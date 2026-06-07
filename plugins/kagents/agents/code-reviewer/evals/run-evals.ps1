#Requires -Version 7.4
<#
.SYNOPSIS
    Spike #251 — Quality-Eval des code-reviewer-Agents gegen lokale Ollama-Modelle.
.DESCRIPTION
    Schickt jede *-input.md (Review-Aufgabe + Code-Ausschnitt) mit dem
    code-reviewer-System-Prompt direkt an Ollama (KEIN K.Switchboard-Proxy) und
    protokolliert pro Modell den Review-Output + Latenz + Peak-RAM nach
    runs/<datum>/code-reviewer-<modell>.md.

    TimeoutSec ist bewusst hoch (Default 1800s), da grosse Modelle (14b) auf
    CPU-only mehrere Minuten pro Review brauchen koennen.

    Peak-RAM-Messung (#268):
    - Baseline free-RAM unmittelbar vor dem ersten Inference-Call je Modell.
    - Inference laeuft in Start-ThreadJob; Foreground-Loop sampelt free-RAM alle
      300 ms und trackt den globalen Minimalwert (= maximale Belegung im Zeitfenster).
    - peakRamDeltaMb = baselineFree - minFree (kann negativ sein wenn Hintergrundprozesse
      RAM freigeben — System-weites Rauschen; Quervergleich via /api/ps empfohlen).
    - Ollama /api/ps nach jedem Call: reported model size (authoritative footprint).
    - Ab dem zweiten Input pro Modell bleibt das Modell warm (keep_alive=10m) ->
      Delta ~0; /api/ps size bleibt zuverlaessig.
.PARAMETER Models
    Zu testende Ollama-Modelle. Default: die code-reviewer-Kandidaten aus #251.
.PARAMETER MaxInputs
    Maximale Anzahl Inputs pro Modell (0 = alle). Fuer defensive Schnelllaeufe.
.PARAMETER TimeoutSec
    HTTP-Timeout fuer jeden Inference-Call. Default: 1800 s.
.EXAMPLE
    ./run-evals.ps1 -Models 'qwen2.5-coder:7b'
.EXAMPLE
    ./run-evals.ps1 -Models 'qwen2.5-coder:14b' -TimeoutSec 2400
#>
param(
    [string[]]$Models     = @('qwen2.5-coder:14b', 'qwen2.5-coder:7b'),
    [string]  $OllamaUrl  = 'http://localhost:11434',
    [string]  $EvalDir    = $PSScriptRoot,
    [int]     $MaxInputs  = 0,
    [int]     $TimeoutSec = 1800
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# ---------------------------------------------------------------------------
# Hilfsfunktion: freier RAM in MB (plattformuebergreifend)
# Gibt 0 zurueck auf macOS (vm_stat-Parsing optional, hier MVP = 0).
# ---------------------------------------------------------------------------
function Get-FreeRamMb {
    if ($IsWindows) {
        return [int]((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024)
    }
    elseif ($IsLinux) {
        # /proc/meminfo: MemAvailable-Zeile
        $memInfoPath = '/proc/meminfo'
        $memPattern  = 'MemAvailable'
        $lines = Get-Content -Path $memInfoPath | Where-Object { $_ -match $memPattern }
        if ($lines -and $lines[0] -match '\d+') {
            return [int]([long]$Matches[0] / 1024)
        }
        return 0
    }
    else { return 0 }
}

# ---------------------------------------------------------------------------
# Hilfsfunktion: Ollama /api/ps -> reported model size in MB
# Gibt $null zurueck wenn Modell nicht geladen oder Fehler.
# ---------------------------------------------------------------------------
function Get-OllamaModelSizeMb {
    param([string]$Model, [string]$BaseUrl)
    try {
        $ps = Invoke-RestMethod -Uri "$BaseUrl/api/ps" -Method Get -TimeoutSec 5 -ErrorAction Stop
        if (-not $ps.PSObject.Properties.Name.Contains('models')) { return $null }
        $entry = $ps.models | Where-Object { $_.name -eq $Model } | Select-Object -First 1
        if ($null -eq $entry) { return $null }
        $sizeBytes = if ($entry.PSObject.Properties.Name.Contains('size')) { [long]$entry.size } else { 0 }
        $vramBytes = if ($entry.PSObject.Properties.Name.Contains('size_vram')) { [long]$entry.size_vram } else { 0 }
        return [PSCustomObject]@{
            SizeMb     = [int]($sizeBytes / 1MB)
            SizeVramMb = [int]($vramBytes / 1MB)
        }
    }
    catch { return $null }
}

# --- System-Prompt: kondensiert aus code-reviewer.agent.md ---
$systemPrompt = @'
Du bist ein erfahrener Code Reviewer fuer .NET (C# 14) und PowerShell Core. Du liest Code,
identifizierst Probleme und gibst konstruktives, konkretes Feedback. Du editierst keinen Code.

Pruefe: Architektur-Konformitaet, Code-Qualitaet (Nullable, async/await korrekt, Exception-Handling,
Naming), Performance (unnoetige Allokationen, fehlendes AsNoTracking), Testbarkeit (DI, statische
Abhaengigkeiten), Wartbarkeit (Magic Strings, Methodenlaenge, Duplikation). Fuer PowerShell zusaetzlich:
Set-StrictMode, Approved Verbs, keine Host-Stream-Ausgaben (Console-Schreiben vermeiden),
Cross-Platform-Pfade, Comment-Based Help, try/catch.

Format je Finding:
### [Severity] Kurztitel
- Datei:Zeile · Kategorie
- Problem: ...
- Empfehlung: ...

Severity: Blocker (funktionaler Fehler/Security) | Wichtig (Pattern-Verletzung/Performance) |
Verbesserung (Lesbarkeit/Syntax) | Hinweis (Diskussion).

Regeln: konstruktiv (immer Empfehlung), lobe guten Code, KEINE erfundenen Probleme, proportional
zum Umfang. Sprache: Deutsch. Wenn der Code in Ordnung ist, sage das explizit.
'@

$today     = Get-Date -Format 'yyyy-MM-dd'
$runDir    = Join-Path $EvalDir "runs/$today"
$null      = New-Item -ItemType Directory -Path $runDir -Force
$allInputs = Get-ChildItem -Path (Join-Path $EvalDir '*-input.md') | Sort-Object Name
$inputs    = if ($MaxInputs -gt 0) { $allInputs | Select-Object -First $MaxInputs } else { $allInputs }

Write-Information "Eval: $($inputs.Count) Inputs x $($Models.Count) Modelle -> $runDir (Timeout ${TimeoutSec}s)"

foreach ($model in $Models) {
    $safe    = $model -replace '[:/]', '-'
    $runFile = Join-Path $runDir "code-reviewer-$safe.md"
    $lines   = @("# Run $today — code-reviewer — $model", '')

    # Baseline free-RAM einmalig vor dem ersten Call fuer dieses Modell.
    $baselineFree  = Get-FreeRamMb
    $globalMinFree = $baselineFree

    foreach ($in in $inputs) {
        $id      = ($in.BaseName -replace '-input$', '')
        $userMsg = Get-Content -Path $in.FullName -Raw
        $body = @{
            model      = $model
            stream     = $false
            keep_alive = '10m'
            messages   = @(
                @{ role = 'system'; content = $systemPrompt },
                @{ role = 'user';   content = $userMsg }
            )
        } | ConvertTo-Json -Depth 8

        try {
            # --- Peak-RAM-Messung ---
            # Inference im Hintergrund (Start-ThreadJob); Sampler im Foreground.
            # Minimales free-RAM im Zeitfenster = maximale RAM-Belegung.
            # HINWEIS: Delta ist systemweit; IDE/Browser-Allokationen koennen
            # Ergebnis verfaelschen. /api/ps size ist zuverlaessiger.
            $preFree          = Get-FreeRamMb
            $inferenceUrl     = "$OllamaUrl/api/chat"
            $inferenceBody    = $body
            $inferenceTimeout = $TimeoutSec

            $job = Start-ThreadJob -ScriptBlock {
                param($url, $reqBody, $tSec)
                Invoke-RestMethod -Uri $url -Method Post -Body $reqBody `
                    -ContentType 'application/json' -TimeoutSec $tSec
            } -ArgumentList $inferenceUrl, $inferenceBody, $inferenceTimeout

            $localMin = $preFree
            try {
                while ($job.State -eq 'Running') {
                    $f = Get-FreeRamMb
                    if ($f -lt $localMin)      { $localMin      = $f }
                    if ($f -lt $globalMinFree) { $globalMinFree = $f }
                    Start-Sleep -Milliseconds 300
                }
                $resp = Receive-Job -Job $job -Wait -ErrorAction Stop
            }
            finally {
                Remove-Job -Job $job -Force
            }

            $peakDelta = $preFree - $localMin

            # Ollama /api/ps fuer reported model size (authoritative, warm oder cold)
            $ollamaSize = Get-OllamaModelSizeMb -Model $model -BaseUrl $OllamaUrl

            $out       = $resp.message.content.Trim()
            $promptTok = if ($resp.PSObject.Properties.Name -contains 'prompt_eval_count') { $resp.prompt_eval_count } else { 0 }
            $evalTok   = if ($resp.PSObject.Properties.Name -contains 'eval_count') { $resp.eval_count } else { 0 }
            $totalS    = if ($resp.PSObject.Properties.Name -contains 'total_duration') { [math]::Round($resp.total_duration / 1e9, 1) } else { 0 }

            $sizeStr = if ($null -ne $ollamaSize) {
                "OllamaSize: $($ollamaSize.SizeMb) MB (VRAM: $($ollamaSize.SizeVramMb) MB)"
            } else { "OllamaSize: n/a" }

            Write-Information "  [$model] $id -> ${totalS}s ($promptTok->$evalTok tok) peak+${peakDelta}MB"
            $lines += @(
                "## $id", '',
                $out, '',
                "_Latenz: ${totalS}s · Input-Tokens: ${promptTok} · Output-Tokens: ${evalTok}_",
                "_PeakRamDeltaMb: ${peakDelta} · ${sizeStr}_",
                '', '---', ''
            )
        }
        catch {
            Write-Information "  [$model] $id -> FEHLER: $($_.Exception.Message)"
            $lines += @("## $id", '', "FEHLER: $($_.Exception.Message)", '', '---', '')
        }
    }

    $baselineDelta = $baselineFree - $globalMinFree
    $lines += @(
        "**Gesamt-Peak (Modell-Baseline -> globales Min):** Baseline ${baselineFree} MB free -> Min ${globalMinFree} MB -> Delta ${baselineDelta} MB",
        ''
    )

    Set-Content -Path $runFile -Value ($lines -join "`n") -Encoding utf8NoBOM
    Write-Information "  -> $runFile"
}

Write-Information "Fertig. Outputs in $runDir — Scoring manuell in results.md eintragen."

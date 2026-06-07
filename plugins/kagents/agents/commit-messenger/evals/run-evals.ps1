#Requires -Version 7.4
<#
.SYNOPSIS
    Spike #251 — Quality-Eval des commit-messenger-Agents gegen lokale Ollama-Modelle.
.DESCRIPTION
    Schickt jede *-input.md (nur der eingebettete ```diff```-Block) mit dem
    commit-messenger-System-Prompt direkt an Ollama (KEIN K.Switchboard-Proxy,
    daher nicht vom 100s-Timeout aus #252 betroffen) und protokolliert pro Modell
    Output + Latenz + Peak-RAM nach runs/<datum>/commit-messenger-<modell>.md.

    Bewusst direkt gegen http://localhost:11434/api/chat (stream:false), damit die
    Qualitaetsfrage orthogonal zur Proxy-Timeout-Frage (#252) bleibt.

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
    Zu testende Ollama-Modelle. Default: die commit-messenger-Kandidaten aus #251.
.PARAMETER MaxInputs
    Maximale Anzahl Inputs pro Modell (0 = alle). Fuer defensive Schnelllaeufe.
.PARAMETER TimeoutSec
    HTTP-Timeout fuer den Inference-Call. Default: 300 s.
.EXAMPLE
    ./run-evals.ps1
.EXAMPLE
    ./run-evals.ps1 -Models 'llama3.2:3b' -MaxInputs 2
#>
param(
    [string[]]$Models     = @('qwen2.5-coder:1.5b', 'llama3.2:3b'),
    [string]  $OllamaUrl  = 'http://localhost:11434',
    [string]  $EvalDir    = $PSScriptRoot,
    [int]     $MaxInputs  = 0,
    [int]     $TimeoutSec = 300
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
        $line = Get-Content -Path $memInfoPath |
            Where-Object { $_ -match 'MemAvailable' } |
            Select-Object -First 1
        if ($line -and $line -match '\d+') {
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

# --- System-Prompt: aus commit-messenger.agent.md (Sektionen 1.2/1.3) ---
$systemPrompt = @'
Du generierst praezise Conventional-Commit-Nachrichten fuer beschriebene Aenderungen.

Ausgabeformat — fuer die Aenderung GENAU EINE Commit-Message (erste Zeile), nichts sonst:
<type>(<scope>): <beschreibung>

Regeln:
- Beschreibung auf Deutsch, Imperativ (nicht "wurde hinzugefuegt" -> "Hinzufuegen")
- type aus: feat, fix, docs, style, refactor, perf, test, chore, ci
- scope aus dem Dateipfad/Kontext ableiten (z.B. switchboard, installer, ci, docs, plugin, hooks)
- Breaking Changes mit ! nach dem Scope: feat(api)!: ...
- Issue-Referenz am Ende wenn im Diff erkennbar: (#42)
- Maximal 72 Zeichen in der ersten Zeile
- Antworte NUR mit der Commit-Message-Zeile, ohne Erklaerung, ohne Code-Fence.
'@

# --- Diff-Block aus einer input.md extrahieren (zwischen ```diff und ```) ---
function Get-DiffBlock {
    param([string]$Path)
    $raw = Get-Content -Path $Path -Raw
    if ($raw -match '(?s)```diff\r?\n(.*?)\r?\n```') { return $Matches[1] }
    throw "Kein ```diff-Block in $Path"
}

$today     = Get-Date -Format 'yyyy-MM-dd'
$runDir    = Join-Path $EvalDir "runs/$today"
$null      = New-Item -ItemType Directory -Path $runDir -Force
$allInputs = Get-ChildItem -Path (Join-Path $EvalDir '*-input.md') | Sort-Object Name
$inputs    = if ($MaxInputs -gt 0) { $allInputs | Select-Object -First $MaxInputs } else { $allInputs }

Write-Information "Eval: $($inputs.Count) Inputs x $($Models.Count) Modelle -> $runDir"

foreach ($model in $Models) {
    $safe    = $model -replace '[:/]', '-'
    $runFile = Join-Path $runDir "commit-messenger-$safe.md"
    $lines   = @("# Run $today — commit-messenger — $model", '')

    # Baseline free-RAM einmalig vor dem ersten Call fuer dieses Modell.
    $baselineFree  = Get-FreeRamMb
    $globalMinFree = $baselineFree

    foreach ($in in $inputs) {
        $id   = ($in.BaseName -replace '-input$', '')
        $diff = Get-DiffBlock -Path $in.FullName
        $body = @{
            model      = $model
            stream     = $false
            keep_alive = '10m'
            messages   = @(
                @{ role = 'system'; content = $systemPrompt },
                @{ role = 'user';   content = "Generiere die Commit-Message fuer folgende Aenderung:`n`n$diff" }
            )
        } | ConvertTo-Json -Depth 8

        try {
            # --- Peak-RAM-Messung ---
            # Inference im Hintergrund (Start-ThreadJob); Sampler im Foreground.
            # Minimales free-RAM im Zeitfenster = maximale RAM-Belegung.
            # HINWEIS: Delta ist systemweit; IDE/Browser-Allokationen koennen
            # Ergebnis verfaelschen. /api/ps size ist zuverlaessiger.
            $preFree         = Get-FreeRamMb
            $inferenceUrl    = "$OllamaUrl/api/chat"
            $inferenceBody   = $body
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

            $peakDelta  = $preFree - $localMin

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
                '```text', $out, '```',
                "- Latenz: **${totalS}s** · Input-Tokens: $promptTok · Output-Tokens: $evalTok",
                "- PeakRamDeltaMb: **${peakDelta}** · ${sizeStr}", ''
            )
        }
        catch {
            Write-Information "  [$model] $id -> FEHLER: $($_.Exception.Message)"
            $lines += @("## $id", '', "FEHLER: $($_.Exception.Message)", '')
        }
    }

    $baselineDelta = $baselineFree - $globalMinFree
    $lines += @(
        '---',
        "**Gesamt-Peak (Modell-Baseline -> globales Min):** Baseline ${baselineFree} MB free -> Min ${globalMinFree} MB -> Delta ${baselineDelta} MB",
        ''
    )

    Set-Content -Path $runFile -Value ($lines -join "`n") -Encoding utf8NoBOM
    Write-Information "  -> $runFile"
}

Write-Information "Fertig. Outputs in $runDir — Scoring manuell in results.md eintragen."

#Requires -Version 7.4
<#
.SYNOPSIS
    Spike #251 — Quality-Eval des code-reviewer-Agents gegen lokale Ollama-Modelle.
.DESCRIPTION
    Schickt jede *-input.md (Review-Aufgabe + Code-Ausschnitt) mit dem
    code-reviewer-System-Prompt direkt an Ollama (KEIN K.Switchboard-Proxy) und
    protokolliert pro Modell den Review-Output + Latenz nach
    runs/<datum>/code-reviewer-<modell>.md.

    TimeoutSec ist bewusst hoch (Default 1800s), da grosse Modelle (14b) auf
    CPU-only mehrere Minuten pro Review brauchen koennen.
.PARAMETER Models
    Zu testende Ollama-Modelle. Default: die code-reviewer-Kandidaten aus #251.
.EXAMPLE
    ./run-evals.ps1 -Models 'qwen2.5-coder:7b'
.EXAMPLE
    ./run-evals.ps1 -Models 'qwen2.5-coder:14b' -TimeoutSec 2400
#>
param(
    [string[]]$Models     = @('qwen2.5-coder:14b', 'qwen2.5-coder:7b'),
    [string]  $OllamaUrl  = 'http://localhost:11434',
    [string]  $EvalDir    = $PSScriptRoot,
    [int]     $TimeoutSec = 1800
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

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

$today  = Get-Date -Format 'yyyy-MM-dd'
$runDir = Join-Path $EvalDir "runs/$today"
$null   = New-Item -ItemType Directory -Path $runDir -Force
$inputs = Get-ChildItem -Path (Join-Path $EvalDir '*-input.md') | Sort-Object Name

Write-Information "Eval: $($inputs.Count) Inputs x $($Models.Count) Modelle -> $runDir (Timeout ${TimeoutSec}s)"

foreach ($model in $Models) {
    $safe    = $model -replace '[:/]', '-'
    $runFile = Join-Path $runDir "code-reviewer-$safe.md"
    $lines   = @("# Run $today — code-reviewer — $model", '')

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
            $resp      = Invoke-RestMethod -Uri "$OllamaUrl/api/chat" -Method Post -Body $body -ContentType 'application/json' -TimeoutSec $TimeoutSec
            $out       = $resp.message.content.Trim()
            $promptTok = if ($resp.PSObject.Properties.Name -contains 'prompt_eval_count') { $resp.prompt_eval_count } else { 0 }
            $evalTok   = if ($resp.PSObject.Properties.Name -contains 'eval_count') { $resp.eval_count } else { 0 }
            $totalS    = if ($resp.PSObject.Properties.Name -contains 'total_duration') { [math]::Round($resp.total_duration / 1e9, 1) } else { 0 }
            Write-Information "  [$model] $id -> ${totalS}s ($promptTok->$evalTok tok)"
            $lines += @("## $id", '', $out, '', "_Latenz: ${totalS}s · Input-Tokens: ${promptTok} · Output-Tokens: ${evalTok}_", '', '---', '')
        }
        catch {
            Write-Information "  [$model] $id -> FEHLER: $($_.Exception.Message)"
            $lines += @("## $id", '', "FEHLER: $($_.Exception.Message)", '', '---', '')
        }
    }

    Set-Content -Path $runFile -Value ($lines -join "`n") -Encoding utf8NoBOM
    Write-Information "  -> $runFile"
}

Write-Information "Fertig. Outputs in $runDir — Scoring manuell in results.md eintragen."

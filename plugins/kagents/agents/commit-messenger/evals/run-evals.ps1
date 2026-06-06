#Requires -Version 7.4
<#
.SYNOPSIS
    Spike #251 — Quality-Eval des commit-messenger-Agents gegen lokale Ollama-Modelle.
.DESCRIPTION
    Schickt jede *-input.md (nur der eingebettete ```diff```-Block) mit dem
    commit-messenger-System-Prompt direkt an Ollama (KEIN K.Switchboard-Proxy,
    daher nicht vom 100s-Timeout aus #252 betroffen) und protokolliert pro Modell
    Output + Latenz nach runs/<datum>/commit-messenger-<modell>.md.

    Bewusst direkt gegen http://localhost:11434/api/chat (stream:false), damit die
    Qualitaetsfrage orthogonal zur Proxy-Timeout-Frage (#252) bleibt.
.PARAMETER Models
    Zu testende Ollama-Modelle. Default: die commit-messenger-Kandidaten aus #251.
.EXAMPLE
    ./run-evals.ps1
.EXAMPLE
    ./run-evals.ps1 -Models 'qwen2.5-coder:1.5b','llama3.2:3b','qwen2.5-coder:7b'
#>
param(
    [string[]]$Models    = @('qwen2.5-coder:1.5b', 'llama3.2:3b'),
    [string]  $OllamaUrl = 'http://localhost:11434',
    [string]  $EvalDir   = $PSScriptRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

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

$today  = Get-Date -Format 'yyyy-MM-dd'
$runDir = Join-Path $EvalDir "runs/$today"
$null   = New-Item -ItemType Directory -Path $runDir -Force
$inputs = Get-ChildItem -Path (Join-Path $EvalDir '*-input.md') | Sort-Object Name

Write-Information "Eval: $($inputs.Count) Inputs x $($Models.Count) Modelle -> $runDir"

foreach ($model in $Models) {
    $safe    = $model -replace '[:/]', '-'
    $runFile = Join-Path $runDir "commit-messenger-$safe.md"
    $lines   = @("# Run $today — commit-messenger — $model", '')

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
            $resp      = Invoke-RestMethod -Uri "$OllamaUrl/api/chat" -Method Post -Body $body -ContentType 'application/json'
            $out       = $resp.message.content.Trim()
            $promptTok = if ($resp.PSObject.Properties.Name -contains 'prompt_eval_count') { $resp.prompt_eval_count } else { 0 }
            $evalTok   = if ($resp.PSObject.Properties.Name -contains 'eval_count') { $resp.eval_count } else { 0 }
            $totalS    = if ($resp.PSObject.Properties.Name -contains 'total_duration') { [math]::Round($resp.total_duration / 1e9, 1) } else { 0 }
            Write-Information "  [$model] $id -> ${totalS}s ($promptTok->$evalTok tok)"
            $lines += @(
                "## $id", '',
                '```text', $out, '```',
                "- Latenz: **${totalS}s** · Input-Tokens: $promptTok · Output-Tokens: $evalTok", ''
            )
        }
        catch {
            Write-Information "  [$model] $id -> FEHLER: $($_.Exception.Message)"
            $lines += @("## $id", '', "FEHLER: $($_.Exception.Message)", '')
        }
    }

    Set-Content -Path $runFile -Value ($lines -join "`n") -Encoding utf8NoBOM
    Write-Information "  -> $runFile"
}

Write-Information "Fertig. Outputs in $runDir — Scoring manuell in results.md eintragen."

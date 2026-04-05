#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    K.Agents Hook: Wird vor jedem Tool-Aufruf ausgefuehrt. Loggt agent_start Events.

.PARAMETER Agent
    Name des aktiven Agenten.

.PARAMETER Model
    Verwendetes Modell (z.B. haiku, sonnet, opus).

.PARAMETER Prompt
    Eingabe-Prompt (wird auf 100 Zeichen gekuerzt).

.PARAMETER SessionId
    Eindeutige Session-ID fuer die aktuelle CLI-Sitzung.

.PARAMETER Cli
    Verwendete CLI: "claude" oder "copilot".
#>
param(
    [string]$Agent = '',
    [string]$Model = '',
    [string]$Prompt = '',
    [string]$SessionId = '',
    [string]$Cli = 'claude'
)

$pluginRoot = if ($env:CLAUDE_PLUGIN_ROOT) { $env:CLAUDE_PLUGIN_ROOT } else { Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
$logDir = Join-Path $pluginRoot 'logs'
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

$logFile = Join-Path $logDir "$(Get-Date -Format 'yyyy-MM-dd').jsonl"

# Log-Rotation: behalte max. 7 Tage
$logs = Get-ChildItem -Path $logDir -Filter '*.jsonl' | Sort-Object Name
if ($logs.Count -gt 7) {
    $logs | Select-Object -First ($logs.Count - 7) | Remove-Item -Force
}

$entry = [ordered]@{
    timestamp      = (Get-Date -Format 'o')
    session_id     = $SessionId
    cli            = $Cli
    event          = 'agent_start'
    agent          = $Agent
    model          = $Model
    prompt_preview = $Prompt.Substring(0, [Math]::Min(100, $Prompt.Length))
} | ConvertTo-Json -Compress

Add-Content -Path $logFile -Value $entry -Encoding utf8

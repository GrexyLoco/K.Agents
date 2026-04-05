#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    K.Agents Hook: Wird nach jedem Tool-Aufruf ausgefuehrt. Loggt agent_complete und agent_handoff Events.

.PARAMETER Agent
    Name des aktiven Agenten.

.PARAMETER TargetAgent
    Name des Ziel-Agenten bei Handoff. Leer wenn kein Handoff.

.PARAMETER SessionId
    Eindeutige Session-ID fuer die aktuelle CLI-Sitzung.

.PARAMETER Cli
    Verwendete CLI: "claude" oder "copilot".

.PARAMETER DurationMs
    Dauer des Tool-Aufrufs in Millisekunden.

.PARAMETER Success
    Gibt an ob der Aufruf erfolgreich war.
#>
param(
    [string]$Agent = '',
    [string]$TargetAgent = '',
    [string]$SessionId = '',
    [string]$Cli = 'claude',
    [int]$DurationMs = 0,
    [bool]$Success = $true
)

$pluginRoot = if ($env:CLAUDE_PLUGIN_ROOT) { $env:CLAUDE_PLUGIN_ROOT } else { Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
$logDir = Join-Path $pluginRoot 'logs'
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logFile = Join-Path $logDir "$(Get-Date -Format 'yyyy-MM-dd').jsonl"

$eventType = if ($TargetAgent) { 'agent_handoff' } else { 'agent_complete' }

$entry = [ordered]@{
    timestamp    = (Get-Date -Format 'o')
    session_id   = $SessionId
    cli          = $Cli
    event        = $eventType
    agent        = $Agent
    target_agent = if ($TargetAgent) { $TargetAgent } else { $null }
    duration_ms  = $DurationMs
    success      = $Success
} | ConvertTo-Json -Compress

Add-Content -Path $logFile -Value $entry -Encoding utf8

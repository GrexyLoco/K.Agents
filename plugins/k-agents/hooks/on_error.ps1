#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    K.Agents Hook: Wird bei Fehlern ausgefuehrt. Loggt error und fallback Events.
    Rate-Limit-Fehler werden als fallback Event mit Ziel-CLI geloggt.

.PARAMETER Agent
    Name des aktiven Agenten.

.PARAMETER SessionId
    Eindeutige Session-ID fuer die aktuelle CLI-Sitzung.

.PARAMETER Cli
    Verwendete CLI: "claude" oder "copilot".

.PARAMETER ErrorType
    Fehlertyp (z.B. "rate_limit", "429", "overloaded").

.PARAMETER ErrorMessage
    Fehlermeldung.
#>
param(
    [string]$Agent = '',
    [string]$SessionId = '',
    [string]$Cli = 'claude',
    [string]$ErrorType = '',
    [string]$ErrorMessage = ''
)

$pluginRoot = if ($env:CLAUDE_PLUGIN_ROOT) { $env:CLAUDE_PLUGIN_ROOT } else { Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
$logDir = Join-Path $pluginRoot 'logs'
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logFile = Join-Path $logDir "$(Get-Date -Format 'yyyy-MM-dd').jsonl"

$isFallback = $ErrorType -match 'rate_limit|429|overloaded|usage_limit'
$eventType  = if ($isFallback) { 'fallback' } else { 'error' }
$fallbackTo = if ($isFallback -and $Cli -eq 'claude') { 'copilot' }
              elseif ($isFallback -and $Cli -eq 'copilot') { 'claude' }
              else { $null }

$entry = [ordered]@{
    timestamp     = (Get-Date -Format 'o')
    session_id    = $SessionId
    cli           = $Cli
    event         = $eventType
    agent         = $Agent
    error_type    = $ErrorType
    error_message = $ErrorMessage
    fallback_to   = $fallbackTo
} | ConvertTo-Json -Compress

Add-Content -Path $logFile -Value $entry -Encoding utf8

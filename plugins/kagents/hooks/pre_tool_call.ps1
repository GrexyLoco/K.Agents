#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    K.Agents Hook: PreToolUse — wird vor jedem Tool-Aufruf ausgefuehrt.
    Loggt tool_name, gekuerzten tool_input, session_id, cwd und permission_mode.
    Erkennt Session-Wechsel und schreibt Session Summary fuer beendete Sessions.
#>

. (Join-Path $PSScriptRoot 'HookHelpers.ps1')

$hookData   = Read-HookStdin
$logFile    = Initialize-LogFile

# Session-Wechsel-Erkennung
$stateFile  = Join-Path (Split-Path $logFile -Parent) '.last-session'
$currentSid = $hookData['session_id']
$lastSid    = if (Test-Path $stateFile) { (Get-Content $stateFile -Raw -Encoding utf8).Trim() } else { $null }

$haveBothSids = -not [string]::IsNullOrWhiteSpace($currentSid) -and -not [string]::IsNullOrWhiteSpace($lastSid)
if ($haveBothSids -and $lastSid -ne $currentSid) {
    try {
        New-SessionSummary -SessionId $lastSid -LogDir (Split-Path $logFile -Parent)
    } catch {
        # Summary-Fehler darf den Tool-Call nicht blockieren
    }
}

if (-not [string]::IsNullOrWhiteSpace($currentSid)) {
    Set-Content -Path $stateFile -Value $currentSid -Encoding utf8 -NoNewline
}

$inputPreview  = Format-InputPreview -HookData $hookData
$correlationId = New-CorrelationId `
    -SessionId $hookData['session_id'] `
    -ToolName  $hookData['tool_name'] `
    -ToolInput $inputPreview

Write-HookLogEntry -LogFile $logFile -Entry ([ordered]@{
    timestamp       = (Get-Date -Format 'o')
    correlation_id  = $correlationId
    session_id      = $hookData['session_id']
    event           = 'pre_tool_use'
    tool_name       = $hookData['tool_name']
    tool_input      = $inputPreview
    cwd             = $hookData['cwd']
    permission_mode = $hookData['permission_mode']
    agent_type      = $hookData['agent_type']
})

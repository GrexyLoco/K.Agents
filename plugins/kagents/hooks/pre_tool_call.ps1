#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    K.Agents Hook: PreToolUse — wird vor jedem Tool-Aufruf ausgefuehrt.
    Loggt tool_name, gekuerzten tool_input, session_id, cwd und permission_mode.
#>

. (Join-Path $PSScriptRoot 'HookHelpers.ps1')

$hookData       = Read-HookStdin
$logFile        = Initialize-LogFile
$inputPreview   = Format-InputPreview -HookData $hookData
$correlationId  = New-CorrelationId `
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

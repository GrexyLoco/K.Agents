#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    K.Agents Hook: PostToolUse — wird nach jedem erfolgreichen Tool-Aufruf ausgefuehrt.
    Loggt tool_name, has_response und correlation_id (fuer pre/post-Zuordnung).
#>

. (Join-Path $PSScriptRoot 'HookHelpers.ps1')

$hookData       = Read-HookStdin
$logFile        = Initialize-LogFile
$inputPreview   = Format-InputPreview -HookData $hookData
$correlationId  = New-CorrelationId `
    -SessionId $hookData['session_id'] `
    -ToolName  $hookData['tool_name'] `
    -ToolInput $inputPreview

$hasResponse = $hookData.ContainsKey('tool_response') -and $null -ne $hookData['tool_response']

Write-HookLogEntry -LogFile $logFile -Entry ([ordered]@{
    timestamp      = (Get-Date -Format 'o')
    correlation_id = $correlationId
    session_id     = $hookData['session_id']
    event          = 'post_tool_use'
    tool_name      = $hookData['tool_name']
    has_response   = $hasResponse
    agent_type     = $hookData['agent_type']
})

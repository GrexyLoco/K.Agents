#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    K.Agents Hook: PostToolUseFailure — wird bei fehlgeschlagenen Tool-Aufrufen ausgefuehrt.
    Loggt tool_name, error, is_interrupt und correlation_id.
#>

. (Join-Path $PSScriptRoot 'HookHelpers.ps1')

$hookData       = Read-HookStdin
$logFile        = Initialize-LogFile
$inputPreview   = Format-InputPreview -HookData $hookData
$correlationId  = New-CorrelationId `
    -SessionId $hookData['session_id'] `
    -ToolName  $hookData['tool_name'] `
    -ToolInput $inputPreview

$errorMsg    = if ($hookData.ContainsKey('error')) { $hookData['error'] } else { '' }
$isInterrupt = if ($hookData.ContainsKey('is_interrupt')) { $hookData['is_interrupt'] } else { $false }

Write-HookLogEntry -LogFile $logFile -Entry ([ordered]@{
    timestamp      = (Get-Date -Format 'o')
    correlation_id = $correlationId
    session_id     = $hookData['session_id']
    event          = 'post_tool_use_failure'
    tool_name      = $hookData['tool_name']
    error          = $errorMsg
    is_interrupt   = $isInterrupt
    agent_type     = $hookData['agent_type']
})

#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    K.Agents Hook: PostToolUse — wird nach jedem Tool-Aufruf ausgefuehrt.

.DESCRIPTION
    Loggt post_tool_use bei Erfolg oder post_tool_use_failure bei Fehler.
    Vereint das frueher auf 'PostToolUseFailure' registrierte on_error.ps1
    in diesen Hook — noetig, weil VS Code Copilot das Event 'PostToolUseFailure'
    nicht unterstuetzt.

    Fehler-Detection: 'tool_response' wird auf 'is_error'-Flag oder 'error'-Key
    untersucht (Claude-Code-Konvention). Ist keines vorhanden, wird der Aufruf
    als Erfolg geloggt.
#>

. (Join-Path $PSScriptRoot 'HookHelpers.ps1')

$hookData       = Read-HookStdin
$logFile        = Initialize-LogFile
$inputPreview   = Format-InputPreview -HookData $hookData
$correlationId  = New-CorrelationId `
    -SessionId $hookData['session_id'] `
    -ToolName  $hookData['tool_name'] `
    -ToolInput $inputPreview

$toolResponse = if ($hookData.ContainsKey('tool_response')) { $hookData['tool_response'] } else { $null }
$hasResponse  = $null -ne $toolResponse

# Fehler-Detection aus tool_response
$isError   = $false
$errorMsg  = ''
if ($toolResponse -is [hashtable]) {
    if ($toolResponse.ContainsKey('is_error') -and $toolResponse['is_error']) {
        $isError  = $true
        $errorMsg = if ($toolResponse.ContainsKey('error')) { [string]$toolResponse['error'] } else { '' }
    } elseif ($toolResponse.ContainsKey('error') -and $toolResponse['error']) {
        $isError  = $true
        $errorMsg = [string]$toolResponse['error']
    }
}

# Top-Level-Felder (fallback, falls Host sie direkt setzt)
if (-not $isError -and $hookData.ContainsKey('error') -and $hookData['error']) {
    $isError  = $true
    $errorMsg = [string]$hookData['error']
}

if ($isError) {
    $isInterrupt = if ($hookData.ContainsKey('is_interrupt')) { [bool]$hookData['is_interrupt'] } else { $false }
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
} else {
    Write-HookLogEntry -LogFile $logFile -Entry ([ordered]@{
        timestamp      = (Get-Date -Format 'o')
        correlation_id = $correlationId
        session_id     = $hookData['session_id']
        event          = 'post_tool_use'
        tool_name      = $hookData['tool_name']
        has_response   = $hasResponse
        agent_type     = $hookData['agent_type']
    })
}

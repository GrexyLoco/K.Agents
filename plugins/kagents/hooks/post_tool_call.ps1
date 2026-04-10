#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    K.Agents Hook: PostToolUse — wird nach jedem erfolgreichen Tool-Aufruf ausgefuehrt.
    Liest den Hook-Kontext als JSON von stdin (Claude Code Hooks-Protokoll).
    Loggt tool_name, gekuerzten tool_input, Erfolg aus tool_response, session_id.
#>

# --- stdin lesen (Claude Code sendet JSON via stdin) ---
$rawInput = try { [Console]::In.ReadToEnd() } catch { '' }
$hookData = if ($rawInput.Trim()) {
    try { $rawInput | ConvertFrom-Json -AsHashtable } catch { @{} }
} else { @{} }

# --- Log-Verzeichnis ---
$pluginRoot = if ($env:CLAUDE_PLUGIN_ROOT) { $env:CLAUDE_PLUGIN_ROOT } else { Split-Path -Parent $PSScriptRoot }
$logDir = Join-Path $pluginRoot 'logs'
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logFile = Join-Path $logDir "$(Get-Date -Format 'yyyy-MM-dd').jsonl"

# --- tool_input auf max. 200 Zeichen kuerzen ---
$toolInputRaw = if ($hookData.ContainsKey('tool_input')) {
    ($hookData['tool_input'] | ConvertTo-Json -Compress -Depth 3)
} else { '' }
$toolInputPreview = if ($toolInputRaw.Length -gt 200) {
    $toolInputRaw.Substring(0, 200) + '...'
} else { $toolInputRaw }

# --- Erfolg: tool_response ist ein String (Rohdaten), nicht null = Erfolg ---
$hasResponse = $hookData.ContainsKey('tool_response') -and $null -ne $hookData['tool_response']
$responsePreview = if ($hasResponse) {
    $raw = [string]$hookData['tool_response']
    if ($raw.Length -gt 200) { $raw.Substring(0, 200) + '...' } else { $raw }
} else { '' }

$entry = [ordered]@{
    timestamp      = (Get-Date -Format 'o')
    session_id     = $hookData['session_id']
    event          = 'post_tool_use'
    tool_name      = $hookData['tool_name']
    tool_input     = $toolInputPreview
    has_response   = $hasResponse
    tool_response  = $responsePreview
    agent_type     = $hookData['agent_type']
} | ConvertTo-Json -Compress

Add-Content -Path $logFile -Value $entry -Encoding utf8

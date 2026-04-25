#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Gemeinsame Hilfsfunktionen fuer K.Agents Claude Code Hooks.

.DESCRIPTION
    Wird per dot-sourcing in pre_tool_call und post_tool_call eingebunden.
    Stellt Funktionen bereit fuer stdin-Lesen, Log-Initialisierung, Korrelations-IDs
    und Input-Vorschau.
#>

function Read-HookStdin {
    <#
    .SYNOPSIS
        Liest JSON von stdin (Claude Code Hooks-Protokoll) und gibt ein Hashtable zurueck.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $rawInput = try { [Console]::In.ReadToEnd() } catch { '' }
    if ($rawInput.Trim()) {
        try { $rawInput | ConvertFrom-Json -AsHashtable } catch { @{} }
    } else { @{} }
}

function Initialize-LogFile {
    <#
    .SYNOPSIS
        Ermittelt den Log-Pfad und erstellt das Verzeichnis bei Bedarf.
    .OUTPUTS
        System.String — vollstaendiger Pfad zur heutigen .jsonl Log-Datei.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $pluginRoot = if ($env:CLAUDE_PLUGIN_ROOT) { $env:CLAUDE_PLUGIN_ROOT } else { Split-Path -Parent $PSScriptRoot }
    $logDir = Join-Path $pluginRoot 'logs'
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    Join-Path $logDir "$(Get-Date -Format 'yyyy-MM-dd').jsonl"
}

function New-CorrelationId {
    <#
    .SYNOPSIS
        Erzeugt eine deterministische Korrelations-ID aus session_id, tool_name und tool_input.
        Gleicher Input in gleicher Session ergibt gleiche ID — ermoeglicht pre/post-Zuordnung.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()][string]$SessionId,
        [AllowNull()][string]$ToolName,
        [AllowNull()][string]$ToolInput
    )

    $payload = "${SessionId}::${ToolName}::${ToolInput}"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
    $hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
    [BitConverter]::ToString($hash, 0, 8).Replace('-', '').ToLower()
}

function Format-InputPreview {
    <#
    .SYNOPSIS
        Kuerzt tool_input auf maximal 200 Zeichen (keine Secrets/Dateiinhalte im Log).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$HookData,

        [int]$MaxLength = 200
    )

    $raw = if ($HookData.ContainsKey('tool_input')) {
        ($HookData['tool_input'] | ConvertTo-Json -Compress -Depth 3)
    } else { '' }

    if ($raw.Length -gt $MaxLength) {
        $raw.Substring(0, $MaxLength) + '...'
    } else { $raw }
}

function Write-HookLogEntry {
    <#
    .SYNOPSIS
        Schreibt einen Log-Eintrag als kompaktes JSON in die tagesaktuelle Log-Datei.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LogFile,

        [Parameter(Mandatory)]
        [System.Collections.Specialized.OrderedDictionary]$Entry
    )

    $json = $Entry | ConvertTo-Json -Compress
    Add-Content -Path $LogFile -Value $json -Encoding utf8
}

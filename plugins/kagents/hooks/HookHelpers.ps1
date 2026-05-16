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

    # Nicht-blockierender Early-Return wenn stdin nicht angeschlossen ist.
    if (-not [Console]::IsInputRedirected) { return @{} }
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

function New-SessionSummary {
<#
.SYNOPSIS
    Berechnet Session-Metriken aus JSONL-Logs und schreibt einen session_summary Eintrag.
.DESCRIPTION
    Liest alle .jsonl-Dateien im LogDir und filtert Events der angegebenen Session.
    Berechnet: Dauer, Tool-Call-Anzahl, Error-Rate, Top-5-Tools.
    Erster Aufruf ohne vorhandene Events schreibt keinen Summary.
.PARAMETER SessionId
    ID der abgeschlossenen Session.
.PARAMETER LogDir
    Verzeichnis mit den .jsonl Log-Dateien.
.EXAMPLE
    New-SessionSummary -SessionId 'abc123' -LogDir '/path/to/logs'
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SessionId,
        [Parameter(Mandatory)][string]$LogDir
    )

    if (-not (Test-Path $LogDir)) { return }

    # Alle Events der Session aus allen .jsonl-Dateien sammeln
    $allEvents = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($logFile in (Get-ChildItem -Path $LogDir -Filter '*.jsonl' | Sort-Object Name)) {
        foreach ($line in (Get-Content $logFile.FullName -Encoding utf8)) {
            if (-not $line.Trim()) { continue }
            try {
                $entry = $line | ConvertFrom-Json -AsHashtable
                if ($entry.ContainsKey('session_id') -and $entry['session_id'] -eq $SessionId) {
                    $null = $allEvents.Add($entry)
                }
            } catch { continue }
        }
    }

    if ($allEvents.Count -eq 0) { return }

    # Metriken berechnen
    $timestamps   = $allEvents | Where-Object { $_.ContainsKey('timestamp') } | ForEach-Object { [datetime]$_['timestamp'] }
    $startTime    = ($timestamps | Sort-Object)[0].ToString('o')
    $endTime      = ($timestamps | Sort-Object -Descending)[0].ToString('o')
    $duration     = [math]::Round((([datetime]$endTime) - ([datetime]$startTime)).TotalMinutes, 1)

    $toolCalls    = @($allEvents | Where-Object { $_.ContainsKey('event') -and $_['event'] -eq 'pre_tool_use' })
    $totalCalls   = $toolCalls.Count
    $errorCount   = @($allEvents | Where-Object { $_.ContainsKey('event') -and $_['event'] -eq 'post_tool_use_failure' }).Count
    $errorRate    = [math]::Round($errorCount / [math]::Max($totalCalls, 1) * 100, 1)

    $uniqueTools  = @($toolCalls | Where-Object { $_.ContainsKey('tool_name') } | ForEach-Object { $_['tool_name'] } | Sort-Object -Unique)

    $toolCounts   = @{}
    foreach ($tc in $toolCalls) {
        if ($tc.ContainsKey('tool_name')) {
            $name = $tc['tool_name']
            $toolCounts[$name] = ($toolCounts[$name] ?? 0) + 1
        }
    }
    $topTools = $toolCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 5 | ForEach-Object {
        [ordered]@{ tool = $_.Key; count = $_.Value }
    }

    # Summary schreiben
    $currentLogFile = Initialize-LogFile
    Write-HookLogEntry -LogFile $currentLogFile -Entry ([ordered]@{
        timestamp          = (Get-Date -Format 'o')
        event              = 'session_summary'
        session_id         = $SessionId
        start_time         = $startTime
        end_time           = $endTime
        duration_minutes   = $duration
        total_tool_calls   = $totalCalls
        unique_tools       = $uniqueTools
        error_count        = $errorCount
        error_rate_percent = $errorRate
        top_tools          = @($topTools)
    })
}

#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Loescht K.Agents Log-Dateien und behaelt die letzten N Tage.

.PARAMETER Keep
    Anzahl der Log-Dateien die behalten werden. Standard: 7.

.EXAMPLE
    .\cleanup-logs.ps1
    # Behaelt die letzten 7 Log-Dateien

.EXAMPLE
    .\cleanup-logs.ps1 -Keep 3
    # Behaelt die letzten 3 Log-Dateien
#>
param(
    [int]$Keep = 7
)

$pluginRoot = if ($env:CLAUDE_PLUGIN_ROOT) { $env:CLAUDE_PLUGIN_ROOT } else { Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
$logDir = Join-Path $pluginRoot 'logs'

if (-not (Test-Path $logDir)) {
    Write-Output "Log-Verzeichnis nicht gefunden: $logDir"
    return
}

$logs = Get-ChildItem -Path $logDir -Filter '*.jsonl' | Sort-Object Name

if ($logs.Count -le $Keep) {
    Write-Output "$($logs.Count) Log-Datei(en) vorhanden, nichts zu bereinigen (Keep: $Keep)."
    return
}

$toRemove = $logs | Select-Object -First ($logs.Count - $Keep)
$toRemove | Remove-Item -Force
Write-Output "$($toRemove.Count) Log-Datei(en) geloescht, $Keep behalten."

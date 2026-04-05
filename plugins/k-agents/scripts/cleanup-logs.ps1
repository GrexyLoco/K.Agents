#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Loescht K.Agents Log-Dateien aelter als N Tage.

.PARAMETER RetentionDays
    Anzahl der Tage, die Logs behalten werden. Standard: 30.

.EXAMPLE
    .\cleanup-logs.ps1
    # Loescht Logs aelter als 30 Tage

.EXAMPLE
    .\cleanup-logs.ps1 -RetentionDays 7
    # Loescht Logs aelter als 7 Tage
#>
param(
    [int]$RetentionDays = 30
)

$logDir = Join-Path $env:USERPROFILE '.k-agents' 'logs'

if (-not (Test-Path $logDir)) {
    Write-Output "Log-Verzeichnis nicht gefunden: $logDir"
    return
}

$cutoff   = (Get-Date).AddDays(-$RetentionDays)
$removed  = Get-ChildItem -Path $logDir -Filter '*.jsonl' |
            Where-Object { $_.LastWriteTime -lt $cutoff }

if ($removed.Count -eq 0) {
    Write-Output "Keine Logs aelter als $RetentionDays Tage gefunden."
    return
}

$removed | Remove-Item -Force
Write-Output "$($removed.Count) Log-Datei(en) geloescht (aelter als $RetentionDays Tage)."

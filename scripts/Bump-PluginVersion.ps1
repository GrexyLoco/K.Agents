#Requires -Version 7.4

<#
.SYNOPSIS
    Bumpt die Plugin-Version in marketplace.json (Single Source of Truth).

.DESCRIPTION
    Die Version wird ausschliesslich in .claude-plugin/marketplace.json gepflegt.
    Beide plugin.json-Dateien (Root + Plugin) haben KEIN version-Feld.
    Claude Code liest die Version aus der marketplace.json.

    Das Script bumpt nach SemVer und committet optional.

.PARAMETER Part
    Welcher Teil gebumpt wird: major, minor oder patch.

.PARAMETER Commit
    Erstellt automatisch einen Conventional Commit.

.EXAMPLE
    .\Bump-PluginVersion.ps1 -Part patch
    # 1.11.0 → 1.11.1

.EXAMPLE
    .\Bump-PluginVersion.ps1 -Part minor -Commit
    # 1.11.0 → 1.12.0, automatisch committet
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('major', 'minor', 'patch')]
    [string]$Part,

    [switch]$Commit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$marketplacePath = Join-Path $repoRoot '.claude-plugin' 'marketplace.json'

if (-not (Test-Path $marketplacePath)) {
    Write-Error "marketplace.json nicht gefunden: $marketplacePath"
}

$marketplace = Get-Content $marketplacePath -Raw | ConvertFrom-Json -AsHashtable
$plugin = $marketplace['plugins'][0]

$currentVersion = $plugin['version']
$parts = $currentVersion -split '\.'
$major = [int]$parts[0]
$minor = [int]$parts[1]
$patch = [int]$parts[2]

switch ($Part) {
    'major' { $major++; $minor = 0; $patch = 0 }
    'minor' { $minor++; $patch = 0 }
    'patch' { $patch++ }
}

$newVersion = "$major.$minor.$patch"
$plugin['version'] = $newVersion
$marketplace['plugins'][0] = $plugin

$marketplace | ConvertTo-Json -Depth 10 | Set-Content $marketplacePath -Encoding utf8

Write-Output "$currentVersion → $newVersion"

if ($Commit) {
    Push-Location $repoRoot
    try {
        git add (Join-Path '.claude-plugin' 'marketplace.json')
        git commit -m "chore(plugin): Version bump $currentVersion → $newVersion"
    } finally {
        Pop-Location
    }
}

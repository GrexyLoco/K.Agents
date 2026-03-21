#!/usr/bin/env pwsh
#Requires -Version 7.4

<#
.SYNOPSIS
    Installiert K.Agents in ein Consumer-Repo.

.DESCRIPTION
    Kopiert oder verlinkt Agents, Skills und Konfigurationsdateien in das
    Ziel-Repository. Unterstützt Copy- und Symlink-Modus.

.PARAMETER TargetPath
    Pfad zum Ziel-Repository. Standard: aktuelles Verzeichnis.

.PARAMETER Mode
    Installationsmodus: 'copy' (Standard) oder 'symlink'.
    Symlink erfordert ggf. Admin-Rechte unter Windows.

.PARAMETER IncludeAgentsmd
    Kopiert AGENTS.md ins Repo-Root. Standard: $true.

.EXAMPLE
    ./scripts/Install-KAgents.ps1 -TargetPath ~/projects/my-app

.EXAMPLE
    ./scripts/Install-KAgents.ps1 -Mode symlink
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TargetPath = (Get-Location).Path,
    [ValidateSet('copy', 'symlink')]
    [string]$Mode = 'copy',
    [bool]$IncludeAgentsmd = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $PSScriptRoot
$pluginRoot = Join-Path $scriptRoot 'plugins' 'k-agents'

$agentsSource = Join-Path $pluginRoot 'agents'
$skillsSource = Join-Path $pluginRoot 'skills'
$agentsTarget = Join-Path $TargetPath '.github' 'agents'
$skillsTarget = Join-Path $TargetPath '.github' 'skills'

# Zielverzeichnisse erstellen
foreach ($dir in @($agentsTarget, $skillsTarget)) {
    if (-not (Test-Path $dir)) {
        if ($PSCmdlet.ShouldProcess($dir, 'Verzeichnis erstellen')) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Information "Erstellt: $dir" -Tags 'Install'
        }
    }
}

if ($Mode -eq 'symlink') {
    # Symlink-Modus: Verlinkt die gesamten Ordner
    if ($PSCmdlet.ShouldProcess($agentsTarget, 'Symlink erstellen')) {
        if (Test-Path $agentsTarget) { Remove-Item $agentsTarget -Force -Recurse }
        New-Item -ItemType SymbolicLink -Path $agentsTarget -Target $agentsSource | Out-Null
        Write-Information "Symlink: $agentsTarget -> $agentsSource" -Tags 'Install'
    }
    if ($PSCmdlet.ShouldProcess($skillsTarget, 'Symlink erstellen')) {
        if (Test-Path $skillsTarget) { Remove-Item $skillsTarget -Force -Recurse }
        New-Item -ItemType SymbolicLink -Path $skillsTarget -Target $skillsSource | Out-Null
        Write-Information "Symlink: $skillsTarget -> $skillsSource" -Tags 'Install'
    }
}
else {
    # Copy-Modus: Kopiert alle Dateien
    $agentFiles = Get-ChildItem -Path $agentsSource -Filter '*.agent.md'
    foreach ($file in $agentFiles) {
        $dest = Join-Path $agentsTarget $file.Name
        if ($PSCmdlet.ShouldProcess($dest, 'Datei kopieren')) {
            Copy-Item -Path $file.FullName -Destination $dest -Force
        }
    }
    Write-Information "$($agentFiles.Count) Agents kopiert" -Tags 'Install'

    $skillDirs = Get-ChildItem -Path $skillsSource -Directory
    foreach ($dir in $skillDirs) {
        $dest = Join-Path $skillsTarget $dir.Name
        if ($PSCmdlet.ShouldProcess($dest, 'Skill kopieren')) {
            Copy-Item -Path $dir.FullName -Destination $dest -Recurse -Force
        }
    }
    Write-Information "$($skillDirs.Count) Skills kopiert" -Tags 'Install'
}

# AGENTS.md kopieren
if ($IncludeAgentsmd) {
    $agentsMdSource = Join-Path $scriptRoot 'AGENTS.md'
    $agentsMdTarget = Join-Path $TargetPath 'AGENTS.md'
    if ($PSCmdlet.ShouldProcess($agentsMdTarget, 'AGENTS.md kopieren')) {
        Copy-Item -Path $agentsMdSource -Destination $agentsMdTarget -Force
        Write-Information "AGENTS.md kopiert" -Tags 'Install'
    }
}

# copilot-instructions.md kopieren
$instructionsSource = Join-Path $scriptRoot '.github' 'copilot-instructions.md'
$instructionsTarget = Join-Path $TargetPath '.github' 'copilot-instructions.md'
if (Test-Path $instructionsSource) {
    if ($PSCmdlet.ShouldProcess($instructionsTarget, 'copilot-instructions.md kopieren')) {
        Copy-Item -Path $instructionsSource -Destination $instructionsTarget -Force
        Write-Information "copilot-instructions.md kopiert" -Tags 'Install'
    }
}

Write-Output "K.Agents erfolgreich installiert in: $TargetPath"
Write-Output "  Modus: $Mode"
Write-Output "  Agents: $(Get-ChildItem -Path $agentsTarget -Filter '*.agent.md' | Measure-Object | Select-Object -ExpandProperty Count)"
Write-Output "  Skills: $(Get-ChildItem -Path $skillsTarget -Directory | Measure-Object | Select-Object -ExpandProperty Count)"

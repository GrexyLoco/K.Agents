#!/usr/bin/env pwsh
#Requires -Version 7.4

<#
.SYNOPSIS
    Aktualisiert K.Agents in den User-Level Verzeichnissen fuer Visual Studio 2026.

.DESCRIPTION
    Entfernt veraltete K.Agents-Dateien und kopiert die aktuelle Version.
    Voraussetzung: Ein aktuelles lokales K.Agents-Repo (git pull vorher ausfuehren).

    Ablauf:
    1. Entfernt alle K.Agents Agents/Skills aus den Zielverzeichnissen
    2. Kopiert die aktuelle Version aus dem lokalen Repo

    Andere Custom Agents/Skills im selben Verzeichnis bleiben erhalten.

.PARAMETER AgentsPath
    Pfad der User-Level Agents. Standard: $env:USERPROFILE\.github\agents

.PARAMETER SkillsPath
    Pfad der User-Level Skills. Standard: $env:USERPROFILE\.github\skills

.EXAMPLE
    ./scripts/Update-KAgentsVS.ps1

.EXAMPLE
    ./scripts/Update-KAgentsVS.ps1 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$AgentsPath = (Join-Path $env:USERPROFILE '.github' 'agents'),
    [string]$SkillsPath = (Join-Path $env:USERPROFILE '.github' 'skills')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $PSScriptRoot
$pluginRoot = Join-Path $scriptRoot 'plugins' 'k-agents'

$agentsSource = Join-Path $pluginRoot 'agents'
$skillsSource = Join-Path $pluginRoot 'skills'

# Tool-Mapping laden (ConvertTo-VS2026AgentContent)
. (Join-Path $PSScriptRoot 'ConvertTo-VS2026AgentContent.ps1')

# Quellverzeichnisse pruefen
if (-not (Test-Path $agentsSource)) {
    Write-Error "Agents-Quelle nicht gefunden: $agentsSource. Bitte aus dem K.Agents-Repo ausfuehren."
}
if (-not (Test-Path $skillsSource)) {
    Write-Error "Skills-Quelle nicht gefunden: $skillsSource. Bitte aus dem K.Agents-Repo ausfuehren."
}

# Zielverzeichnisse erstellen falls noetig
foreach ($dir in @($AgentsPath, $SkillsPath)) {
    if (-not (Test-Path $dir)) {
        if ($PSCmdlet.ShouldProcess($dir, 'Verzeichnis erstellen')) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
}

# --- Phase 1: Veraltete K.Agents-Dateien entfernen ---

$knownAgents = Get-ChildItem -Path $agentsSource -Filter '*.agent.md' | Select-Object -ExpandProperty Name
$knownSkills = Get-ChildItem -Path $skillsSource -Directory | Select-Object -ExpandProperty Name

$removedAgents = 0
foreach ($name in $knownAgents) {
    $target = Join-Path $AgentsPath $name
    if (Test-Path $target) {
        if ($PSCmdlet.ShouldProcess($target, 'Veralteten Agent entfernen')) {
            Remove-Item -Path $target -Force
            $removedAgents++
        }
    }
}

$removedSkills = 0
foreach ($name in $knownSkills) {
    $target = Join-Path $SkillsPath $name
    if (Test-Path $target) {
        if ($PSCmdlet.ShouldProcess($target, 'Veralteten Skill entfernen')) {
            Remove-Item -Path $target -Recurse -Force
            $removedSkills++
        }
    }
}

# --- Phase 2: Aktuelle Version kopieren (mit Tool-Mapping VS Code → VS 2026) ---

$agentFiles = Get-ChildItem -Path $agentsSource -Filter '*.agent.md'
foreach ($file in $agentFiles) {
    $dest = Join-Path $AgentsPath $file.Name
    if ($PSCmdlet.ShouldProcess($dest, 'Agent kopieren')) {
        $content = Get-Content -Path $file.FullName -Raw
        $transformed = ConvertTo-VS2026AgentContent -Content $content
        Set-Content -Path $dest -Value $transformed -NoNewline
    }
}

$skillDirs = Get-ChildItem -Path $skillsSource -Directory
foreach ($dir in $skillDirs) {
    $dest = Join-Path $SkillsPath $dir.Name
    if ($PSCmdlet.ShouldProcess($dest, 'Skill kopieren')) {
        Copy-Item -Path $dir.FullName -Destination $dest -Recurse -Force
    }
}

Write-Output "Update abgeschlossen:"
Write-Output "  $($agentFiles.Count) Agents ($removedAgents ersetzt, $($agentFiles.Count - $removedAgents) neu)"
Write-Output "  $($skillDirs.Count) Skills ($removedSkills ersetzt, $($skillDirs.Count - $removedSkills) neu)"
Write-Output ''
Write-Output 'Visual Studio 2026 neu starten, damit die Aenderungen wirksam werden.'

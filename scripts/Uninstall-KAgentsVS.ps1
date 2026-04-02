#!/usr/bin/env pwsh
#Requires -Version 7.4

<#
.SYNOPSIS
    Deinstalliert K.Agents aus den User-Level Verzeichnissen fuer Visual Studio 2026.

.DESCRIPTION
    Entfernt nur die Agents und Skills, die aus K.Agents stammen.
    Andere Custom Agents/Skills im selben Verzeichnis bleiben erhalten.

    Die Zuordnung erfolgt ueber den Dateinamen (Agents) bzw. Ordnernamen (Skills),
    abgeglichen mit dem lokalen K.Agents-Repo unter plugins/k-agents/.

.PARAMETER AgentsPath
    Pfad der User-Level Agents. Standard: $env:USERPROFILE\.github\agents

.PARAMETER SkillsPath
    Pfad der User-Level Skills. Standard: $env:USERPROFILE\.github\skills

.EXAMPLE
    ./scripts/Uninstall-KAgentsVS.ps1

.EXAMPLE
    ./scripts/Uninstall-KAgentsVS.ps1 -WhatIf
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

# Quellverzeichnisse pruefen
if (-not (Test-Path $agentsSource)) {
    Write-Error "Agents-Quelle nicht gefunden: $agentsSource. Bitte aus dem K.Agents-Repo ausfuehren."
}
if (-not (Test-Path $skillsSource)) {
    Write-Error "Skills-Quelle nicht gefunden: $skillsSource. Bitte aus dem K.Agents-Repo ausfuehren."
}

# K.Agents-Dateinamen ermitteln
$knownAgents = Get-ChildItem -Path $agentsSource -Filter '*.agent.md' | Select-Object -ExpandProperty Name
$knownSkills = Get-ChildItem -Path $skillsSource -Directory | Select-Object -ExpandProperty Name

# Agents entfernen
$removedAgents = 0
foreach ($name in $knownAgents) {
    $target = Join-Path $AgentsPath $name
    if (Test-Path $target) {
        if ($PSCmdlet.ShouldProcess($target, 'Agent entfernen')) {
            Remove-Item -Path $target -Force
            $removedAgents++
        }
    }
}
Write-Output "$removedAgents/$($knownAgents.Count) Agents entfernt aus: $AgentsPath"

# Skills entfernen
$removedSkills = 0
foreach ($name in $knownSkills) {
    $target = Join-Path $SkillsPath $name
    if (Test-Path $target) {
        if ($PSCmdlet.ShouldProcess($target, 'Skill entfernen')) {
            Remove-Item -Path $target -Recurse -Force
            $removedSkills++
        }
    }
}
Write-Output "$removedSkills/$($knownSkills.Count) Skills entfernt aus: $SkillsPath"

Write-Output ''
Write-Output 'Deinstallation abgeschlossen.'
Write-Output '  Visual Studio 2026 neu starten, damit die Aenderungen wirksam werden.'

#!/usr/bin/env pwsh
#Requires -Version 7.4

<#
.SYNOPSIS
    Installiert K.Agents auf User-Level fuer Visual Studio 2026 (18.5+).

.DESCRIPTION
    Kopiert Agents und Skills in die User-Level Verzeichnisse, die Visual Studio 2026
    automatisch erkennt. Kein Plugin-Marketplace noetig.

    - Agents → %USERPROFILE%\.github\agents\
    - Skills → %USERPROFILE%\.github\skills\

    Dieses Skript muss aus dem K.Agents-Repo-Verzeichnis heraus ausgefuehrt werden,
    oder das Repo wird automatisch ueber den Skript-Pfad ermittelt.

.PARAMETER AgentsPath
    Zielpfad fuer Agents. Standard: $env:USERPROFILE\.github\agents

.PARAMETER SkillsPath
    Zielpfad fuer Skills. Standard: $env:USERPROFILE\.github\skills

.EXAMPLE
    ./scripts/Install-KAgentsVS.ps1

.EXAMPLE
    ./scripts/Install-KAgentsVS.ps1 -WhatIf

.EXAMPLE
    ./scripts/Install-KAgentsVS.ps1 -AgentsPath "D:\custom\.github\agents"
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

# Tool-Bereinigung laden (ConvertTo-VS2026AgentContent)
. (Join-Path $PSScriptRoot 'ConvertTo-VS2026AgentContent.ps1')

# Quellverzeichnisse pruefen
if (-not (Test-Path $agentsSource)) {
    Write-Error "Agents-Quelle nicht gefunden: $agentsSource. Bitte aus dem K.Agents-Repo ausfuehren."
}
if (-not (Test-Path $skillsSource)) {
    Write-Error "Skills-Quelle nicht gefunden: $skillsSource. Bitte aus dem K.Agents-Repo ausfuehren."
}

# Zielverzeichnisse erstellen
foreach ($dir in @($AgentsPath, $SkillsPath)) {
    if (-not (Test-Path $dir)) {
        if ($PSCmdlet.ShouldProcess($dir, 'Verzeichnis erstellen')) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Information "Erstellt: $dir" -Tags 'Install'
        }
    }
}

# Agents kopieren (VS Code-spezifische Tools entfernen)
$agentFiles = Get-ChildItem -Path $agentsSource -Filter '*.agent.md'
foreach ($file in $agentFiles) {
    $dest = Join-Path $AgentsPath $file.Name
    if ($PSCmdlet.ShouldProcess($dest, 'Agent kopieren')) {
        $content = Get-Content -Path $file.FullName -Raw
        $transformed = ConvertTo-VS2026AgentContent -Content $content
        Set-Content -Path $dest -Value $transformed -NoNewline
    }
}
Write-Output "$($agentFiles.Count) Agents kopiert nach: $AgentsPath"

# Skills kopieren (jeder Skill ist ein Unterordner)
$skillDirs = Get-ChildItem -Path $skillsSource -Directory
foreach ($dir in $skillDirs) {
    $dest = Join-Path $SkillsPath $dir.Name
    if ($PSCmdlet.ShouldProcess($dest, 'Skill kopieren')) {
        Copy-Item -Path $dir.FullName -Destination $dest -Recurse -Force
    }
}
Write-Output "$($skillDirs.Count) Skills kopiert nach: $SkillsPath"

Write-Output ''
Write-Output 'Installation abgeschlossen.'
Write-Output '  Visual Studio 2026 neu starten oder Solution erneut oeffnen.'
Write-Output '  Agents erscheinen im Agent Picker (Copilot Chat).'
Write-Output '  Skills werden automatisch entdeckt.'

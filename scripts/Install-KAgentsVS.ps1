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

    Am Ende wird automatisch das Copilot Instructions Template (global)
    installiert, damit Copilot Chat den Orchestrator und die CLIs kennt.
    Mit -SkipInstructions kann das uebersprungen werden.

.PARAMETER AgentsPath
    Zielpfad fuer Agents. Standard: $env:USERPROFILE\.github\agents

.PARAMETER SkillsPath
    Zielpfad fuer Skills. Standard: $env:USERPROFILE\.github\skills

.PARAMETER SkipInstructions
    Ueberspringt die Installation der Copilot Instructions.

.EXAMPLE
    ./scripts/Install-KAgentsVS.ps1

.EXAMPLE
    ./scripts/Install-KAgentsVS.ps1 -WhatIf

.EXAMPLE
    ./scripts/Install-KAgentsVS.ps1 -SkipInstructions

.EXAMPLE
    ./scripts/Install-KAgentsVS.ps1 -AgentsPath "D:\custom\.github\agents"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$AgentsPath = (Join-Path $env:USERPROFILE '.github' 'agents'),
    [string]$SkillsPath = (Join-Path $env:USERPROFILE '.github' 'skills'),
    [switch]$SkipInstructions
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $PSScriptRoot
$pluginRoot = Join-Path $scriptRoot 'plugins' 'kagents'

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

$knownAgents = Get-ChildItem -Path $agentsSource -Filter '*.agent.md' | Select-Object -ExpandProperty Name

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
# Guard: Wenn das K.Agents Copilot-Plugin installiert ist, werden Agents NICHT nach
# ~/.github/agents/ kopiert, da das Plugin bereits als primäre Quelle dient.
# Doppelte Einträge im VS Code Agent Picker werden so verhindert. (#163)
$copilotPluginAgentsPath = Join-Path $env:USERPROFILE '.copilot' 'installed-plugins' 'kagents' 'kagents' 'agents'
$copilotPluginInstalled = Test-Path $copilotPluginAgentsPath

if ($copilotPluginInstalled) {
    Write-Information "K.Agents Copilot-Plugin erkannt ($copilotPluginAgentsPath)." -Tags 'Install'
    $removedLegacyAgents = 0
    foreach ($name in $knownAgents) {
        $target = Join-Path $AgentsPath $name
        if (Test-Path $target) {
            if ($PSCmdlet.ShouldProcess($target, 'Legacy-K.Agents-Agent entfernen (Plugin uebernimmt)')) {
                Remove-Item -Path $target -Force
                $removedLegacyAgents++
            }
        }
    }
    Write-Information "Agents werden NICHT nach $AgentsPath kopiert, um Duplikate im Agent Picker zu vermeiden." -Tags 'Install'
    Write-Output "Agents-Kopie uebersprungen: Copilot-Plugin bereits installiert (Duplikat-Schutz aktiv)."
    Write-Output "$removedLegacyAgents Legacy-K.Agents-Agents in $AgentsPath bereinigt."
    $agentFiles = @()
} else {
    $agentFiles = Get-ChildItem -Path $agentsSource -Filter '*.agent.md'
    foreach ($file in $agentFiles) {
        $dest = Join-Path $AgentsPath $file.Name
        if ($PSCmdlet.ShouldProcess($dest, 'Agent kopieren')) {
            if (-not (Test-Path $AgentsPath)) {
                New-Item -ItemType Directory -Path $AgentsPath -Force | Out-Null
            }
            $content = Get-Content -Path $file.FullName -Raw
            $transformed = ConvertTo-VS2026AgentContent -Content $content
            Set-Content -Path $dest -Value $transformed -NoNewline
        }
    }
    Write-Output "$($agentFiles.Count) Agents kopiert nach: $AgentsPath"
}

# Skills kopieren (jeder Skill ist ein Unterordner)
$skillDirs = Get-ChildItem -Path $skillsSource -Directory
foreach ($dir in $skillDirs) {
    $dest = Join-Path $SkillsPath $dir.Name
    if ($PSCmdlet.ShouldProcess($dest, 'Skill kopieren')) {
        if (-not (Test-Path $SkillsPath)) {
            New-Item -ItemType Directory -Path $SkillsPath -Force | Out-Null
        }
        Copy-Item -Path $dir.FullName -Destination $dest -Recurse -Force
    }
}
Write-Output "$($skillDirs.Count) Skills kopiert nach: $SkillsPath"

# --- Phase 3: Copilot Instructions installieren (global) ---

if (-not $SkipInstructions) {
    $setupScript = Join-Path $PSScriptRoot 'Setup-Instructions.ps1'
    if (Test-Path $setupScript) {
        if ($PSCmdlet.ShouldProcess("$env:USERPROFILE\.github\copilot-instructions.md", 'Instructions installieren')) {
            & $setupScript -Force
        }
    } else {
        Write-Warning "Setup-Instructions.ps1 nicht gefunden: $setupScript"
    }
}

Write-Output ''
Write-Output 'Installation abgeschlossen.'
Write-Output '  Visual Studio 2026 neu starten oder Solution erneut oeffnen.'
Write-Output '  Agents erscheinen im Agent Picker (Copilot Chat).'
Write-Output '  Skills werden automatisch entdeckt.'

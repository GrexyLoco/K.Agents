#Requires -Version 7.4

<#
.SYNOPSIS
    Kopiert K.Agents Copilot Instructions in ein Repo oder global.

.DESCRIPTION
    Installiert das copilot-instructions.md Template aus K.Agents in ein
    einzelnes Repo oder als globale Konfiguration fuer alle Repos.

    Das Template erklaert Copilot Chat, wie der Orchestrator und die
    spezialisierten Agenten zu verwenden sind, und welche CLI-Tools
    (claude, copilot) zur Verfuegung stehen.

    Ohne -Path werden die Instructions global installiert nach
    $env:USERPROFILE\.github\copilot-instructions.md — damit gelten
    sie fuer alle Repos, die keine eigene copilot-instructions.md haben.

.PARAMETER Path
    Ziel-Repo-Pfad. Wenn nicht angegeben: globale Installation nach
    $env:USERPROFILE\.github\copilot-instructions.md.

.PARAMETER Force
    Ueberschreibt existierende Instructions ohne Rueckfrage.

.EXAMPLE
    .\Setup-Instructions.ps1 -Path C:\repos\MyProject
    Installiert Instructions in C:\repos\MyProject\.github\copilot-instructions.md

.EXAMPLE
    .\Setup-Instructions.ps1
    Installiert Instructions global nach $env:USERPROFILE\.github\copilot-instructions.md

.EXAMPLE
    .\Setup-Instructions.ps1 -Path C:\repos\MyProject -Force
    Ueberschreibt existierende Instructions ohne Rueckfrage
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Path,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $PSScriptRoot
$templatePath = Join-Path $scriptRoot 'plugins' 'kagents' 'templates' 'copilot-instructions.md'

if (-not (Test-Path $templatePath)) {
    throw "Template nicht gefunden: $templatePath"
}

if ($Path) {
    $targetDir  = Join-Path $Path '.github'
    $targetFile = Join-Path $targetDir 'copilot-instructions.md'
    $scope      = "Repo ($Path)"
} else {
    $targetDir  = Join-Path $env:USERPROFILE '.github'
    $targetFile = Join-Path $targetDir 'copilot-instructions.md'
    $scope      = 'global'
}

if ((Test-Path $targetFile) -and -not $Force) {
    Write-Warning "Instructions existieren bereits: $targetFile"
    Write-Warning "Nutze -Force zum Ueberschreiben."
    return
}

if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

Copy-Item -Path $templatePath -Destination $targetFile -Force
Write-Output "K.Agents Instructions installiert ($scope): $targetFile"

if ($Path) {
    Write-Output ''
    Write-Output 'Naechste Schritte:'
    Write-Output "1. Projekt-Kontext anpassen: code `"$targetFile`""
    Write-Output "2. Commit: git -C `"$Path`" add .github/copilot-instructions.md"
    Write-Output "          git -C `"$Path`" commit -m 'chore: K.Agents Copilot Instructions hinzugefuegt'"
}

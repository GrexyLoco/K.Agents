---
name: powershell-module-design
description: PowerShell Core Modul-Design und Cross-Platform Best Practices. Nutze diesen Skill bei der Strukturierung von PowerShell-Modulen, Scripts und CI-Skripten.
---

# PowerShell Module Design

## Datei-Header (Pflicht an jeder .ps1)
```powershell
#Requires -Version 7.4
```

## Script-Initialisierung (Pflicht)
```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
```

## Verzeichnisstruktur
```
ModuleName/
├── ModuleName.psd1              # Manifest
├── ModuleName.psm1              # Root Module (Dot-Sourcing)
├── Functions/
│   ├── Public/                  # Exportierte Functions
│   └── Private/
│       └── Handlers/            # Sub-Kategorie für Spezialisten
├── Tests/
│   ├── ModuleName.Feature.Tests.ps1
│   └── FunctionName.Tests.ps1
├── .github/
│   ├── scripts/                 # CI-Hilfsscripts
│   ├── workflows/
│   └── linters/
└── action.yml                   # GitHub Action Interface (optional)
```

## Root Module: Dot-Sourcing-Reihenfolge
Handlers → Private → Public (Abhängigkeitsrichtung):
```powershell
$script:ModuleRoot = $PSScriptRoot
$handlerFunctions = @(Get-ChildItem -Path (Join-Path $script:ModuleRoot 'Functions' 'Private' 'Handlers') -Filter '*.ps1' -ErrorAction SilentlyContinue)
foreach ($file in $handlerFunctions) {
    try { . $file.FullName; Write-Verbose "Loaded handler: $($file.BaseName)" }
    catch { Write-Error "Failed to load '$($file.Name)': $_"; throw }
}
# dann Private, dann Public analog
```

## ⛔ Cross-Platform Hard Rules (überall, auch CI)
- `Write-Host` → `Write-Output`, `Write-Verbose`, `Write-Information`
- `"$root\sub"` → `Join-Path $root 'sub'`
- `$env:USERPROFILE` → `$env:HOME`
- `\r\n` → `[Environment]::NewLine`
- `Get-WmiObject` → `Get-CimInstance`
- Encoding: immer `-Encoding utf8`
- Null-Check: `$null -eq $variable` (nicht umgekehrt)

## GitHub Actions Output-Pattern
```powershell
if ($env:GITHUB_OUTPUT) {
    "output-name=$value" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
}
```

## Function-Design
- Approved Verbs, `[CmdletBinding()]`, Parameter-Validation
- Comment-Based Help: `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`
- `ShouldProcess` bei destruktiven Operationen
- Einheitliche Result-Objects:
```powershell
[PSCustomObject]@{ Passed = $true; Skipped = $false; Message = '...' }
```

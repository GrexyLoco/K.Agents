---
name: powershell-module-design
description: "PowerShell Core module design — .psd1/.psm1 manifests, Public/Private/Handlers folder structure, dot-sourcing order, CmdletBinding, Set-StrictMode, cross-platform rules (no Write-Host, Join-Path), PSScriptAnalyzer. USE FOR: structuring new PowerShell modules, implementing cross-platform functions, writing CI scripts. DO NOT USE FOR: PowerShell tests (use pester-patterns) or GitHub Actions workflows (use github-actions-patterns)."
---

# 1. PowerShell Module Design

## 1.1 Datei-Header (Pflicht an jeder .ps1)
```powershell
#Requires -Version 7.4
```

## 1.2 Script-Initialisierung (Pflicht)
```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
```

## 1.3 Verzeichnisstruktur
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

## 1.4 Root Module: Dot-Sourcing-Reihenfolge
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

## 1.5 ⛔ Cross-Platform Hard Rules (überall, auch CI)
- `Write-Host` → `Write-Output`, `Write-Verbose`, `Write-Information`
- `"$root\sub"` → `Join-Path $root 'sub'`
- `$env:USERPROFILE` → `$env:HOME`
- `\r\n` → `[Environment]::NewLine`
- `Get-WmiObject` → `Get-CimInstance`
- Encoding: immer `-Encoding utf8`
- Null-Check: `$null -eq $variable` (nicht umgekehrt)

## 1.6 GitHub Actions Output-Pattern
```powershell
if ($env:GITHUB_OUTPUT) {
    "output-name=$value" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
}
```

## 1.7 Function-Design
- Approved Verbs, `[CmdletBinding()]`, Parameter-Validation
- Comment-Based Help: `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`
- `ShouldProcess` bei destruktiven Operationen
- Einheitliche Result-Objects:
```powershell
[PSCustomObject]@{ Passed = $true; Skipped = $false; Message = '...' }
```

## 1.8 PSScriptAnalyzer-Review-Policy
Nur **Error** und **Warning** Severity prüfen — Information-Findings ignorieren.
Keine `ExcludeRules` erlaubt (Regeln dürfen nicht unterdrückt werden).

```powershell
# CI-Aufruf (konform zur Policy)
Invoke-ScriptAnalyzer -Path . -Recurse -Severity @('Error', 'Warning')
```

Findings der Severity **Error** blockieren den Build.
Findings der Severity **Warning** werden als Review-Kommentar gemeldet, blockieren nicht.

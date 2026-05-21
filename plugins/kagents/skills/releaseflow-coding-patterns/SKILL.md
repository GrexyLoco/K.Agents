---
name: releaseflow-coding-patterns
description: "K.Actions.ReleaseFlow implementation patterns — unified Result-Objects, version-handler pattern, GitHub Actions output helpers, New-TestContext test factory, dot-sourcing conventions, strict mode boilerplate. USE FOR: implementing or modifying K.Actions.ReleaseFlow module code, following ReleaseFlow-specific coding conventions. DO NOT USE FOR: general PowerShell design (use powershell-module-design), general Pester tests (use pester-patterns), or ReleaseFlow process knowledge (use releaseflow-domain)."
---

# 1. ReleaseFlow Coding Patterns

## 1.1 PowerShell-Modul-Konventionen

### 1.1.1 Datei-Header (Pflicht an jeder .ps1 Datei)
```powershell
#Requires -Version 7.4
```

### 1.1.2 Strict Mode (Pflicht in Scripts und .psm1)
```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
```

### 1.1.3 Modul-Struktur
```
ModuleName/
├── ModuleName.psd1              # Manifest
├── ModuleName.psm1              # Root Module (Dot-Sourcing)
├── Functions/
│   ├── Public/                  # Exportierte Functions (max 2-3)
│   │   ├── New-Release.ps1
│   │   └── New-ReleaseTrain.ps1
│   └── Private/                 # Interne Functions
│       ├── Get-ReleaseContext.ps1
│       ├── Test-ReleaseGuardrails.ps1
│       └── Handlers/            # Sub-Kategorie für Spezialisten
│           ├── Update-PowerShellVersion.ps1
│           └── Update-DotNetVersion.ps1
├── Tests/
│   ├── ModuleName.Feature.Tests.ps1
│   └── INTEGRATION-TEST-PLAN.md
└── action.yml                   # GitHub Action Interface
```

### 1.1.4 Dot-Sourcing-Reihenfolge im .psm1
```powershell
$script:ModuleRoot = $PSScriptRoot

# 1. Handlers zuerst (werden von Private Functions benötigt)
$handlerFunctions = @(Get-ChildItem -Path "$script:ModuleRoot/Functions/Private/Handlers" -Filter '*.ps1' -ErrorAction SilentlyContinue)
foreach ($file in $handlerFunctions) {
    try { . $file.FullName; Write-Verbose "Loaded handler: $($file.BaseName)" }
    catch { Write-Error "Failed to load handler '$($file.Name)': $_"; throw }
}

# 2. Private Functions
$privateFunctions = @(Get-ChildItem -Path "$script:ModuleRoot/Functions/Private" -Filter '*.ps1' -ErrorAction SilentlyContinue)
foreach ($file in $privateFunctions) {
    try { . $file.FullName; Write-Verbose "Loaded private: $($file.BaseName)" }
    catch { Write-Error "Failed to load private '$($file.Name)': $_"; throw }
}

# 3. Public Functions zuletzt
$publicFunctions = @(Get-ChildItem -Path "$script:ModuleRoot/Functions/Public" -Filter '*.ps1' -ErrorAction SilentlyContinue)
foreach ($file in $publicFunctions) {
    try { . $file.FullName; Write-Verbose "Loaded public: $($file.BaseName)" }
    catch { Write-Error "Failed to load public '$($file.Name)': $_"; throw }
}
```

### 1.1.5 Function-Pattern (Guardrail-Stil)
Jede Guardrail-Function gibt ein einheitliches Result-Object zurück:
```powershell
[PSCustomObject]@{
    Passed  = $true/$false
    Skipped = $true/$false
    Message = 'Beschreibung des Ergebnisses'
}
```

### 1.1.6 GitHub Actions Output-Pattern
```powershell
if ($env:GITHUB_OUTPUT) {
    "output-name=$value" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
}
```

### 1.1.7 Version-Handler-Pattern
Separate Handler pro Projekttyp in `Functions/Private/Handlers/`:
- `Update-PowerShellVersion.ps1` → `.psd1` (ModuleVersion, Prerelease)
- `Update-DotNetVersion.ps1` → `.csproj` / `Directory.Build.props` (VersionPrefix, VersionSuffix)
- Commit mit `[skip ci]` um Endlosschleifen zu verhindern

## 1.2 Pester-Test-Konventionen

### 1.2.1 Test-Helper-Pattern
```powershell
#region Helper Functions (Script Scope)

function script:New-TestContext {
    param(
        [string]$Phase = 'alpha',
        [string]$Version = 'v1.0.0',
        [string]$SourceBranch = 'feature/test',
        [string]$TargetBranch = 'dev/v1.0.0',
        [object]$Intent = $null,
        [string]$Repository = 'TestOwner/TestRepo',
        [int]$PullRequest = 42
    )
    [PSCustomObject]@{
        Phase        = $Phase
        Version      = $Version
        SourceBranch = $SourceBranch
        TargetBranch = $TargetBranch
        Intent       = $Intent
        Repository   = $Repository
        PullRequest  = $PullRequest
    }
}

#endregion
```

### 1.2.2 InModuleScope-Pattern für Private Functions
```powershell
InModuleScope $script:TestModule.Name -Parameters @{ Context = $ctx } {
    param($Context)
    $result = Test-G1DevGate -Context $Context
    $result.Passed | Should -BeTrue
}
```

### 1.2.3 Mock-Pattern für GitHub CLI (`gh`)
```powershell
Mock gh {
    $script:LASTEXITCODE = 0
    return '{"name":"release/v1.0.0"}'
}

# Mit ParameterFilter für unterschiedliche gh-Aufrufe
Mock gh {
    if (($args -join ' ') -match 'pr view.*statusCheckRollup') {
        $script:LASTEXITCODE = 0
        return '{"statusCheckRollup":[{"name":"test","conclusion":"SUCCESS"}]}'
    }
    if (($args -join ' ') -match 'api.*releases') {
        $script:LASTEXITCODE = 0
        return '[]'
    }
}
```

### 1.2.4 Mock-Pattern für Git-Befehle
```powershell
Mock git { return 'v1.0.0-freeze' } -ParameterFilter { $args[0] -eq 'tag' -and $args[1] -eq '-l' }
```

### 1.2.5 Test-Datei-Benennung
- `ModuleName.Feature.Tests.ps1` (z.B. `K.Actions.ReleaseFlow.Guardrails.Tests.ps1`)
- `FunctionName.Tests.ps1` (z.B. `New-FreezeRelease.Tests.ps1`)
- `ScriptName.Tests.ps1` (z.B. `Invoke-QualityGateEvaluation.Tests.ps1`)

### 1.2.6 BeforeAll/AfterAll-Pattern
```powershell
BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' 'K.Actions.ReleaseFlow.psd1'
    $script:TestModule = Import-Module $modulePath -Force -PassThru
}

AfterAll {
    if ($script:TestModule) {
        Remove-Module $script:TestModule.Name -Force -ErrorAction SilentlyContinue
    }
}
```

## 1.3 Quality Gate Workflow-Pattern

```yaml
# Wiederverwendbar als workflow_call UND direkt als pull_request
on:
  pull_request:
    branches: [master, main, 'dev/v*', 'release/v*']
    paths-ignore: ['**/*.md', 'examples/**']
  workflow_call:
    outputs:
      quality-success:
        value: ${{ jobs.quality-gate.outputs.quality-success }}
```

### 1.3.1 Quality Gate Steps (Reihenfolge)
1. Checkout (fetch-depth: 0)
2. Action-Metadaten ermitteln
3. GitLeaks Security Scan
4. Strukturvalidierung
5. PSScriptAnalyzer Lint
6. Pester Tests
7. Quality Gate Evaluation (aggregiert alle Ergebnisse)
8. Summary schreiben

### 1.3.2 PSScriptAnalyzer-Konfiguration
```powershell
@{
    Severity = @('Error', 'Warning')  # Information ignorieren
    ExcludeRules = @()                # Keine Ausnahmen
}
```

## 1.4 CI-Script-Konventionen (.github/scripts/)

- Jedes Script hat Comment-Based Help (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.OUTPUTS`, `.EXAMPLE`)
- `[CmdletBinding()]` + `param()` Block
- GitHub Outputs via `$env:GITHUB_OUTPUT`
- Keine `Write-Host` — verwende `Write-Information`, `Write-Verbose`, `Write-Output`
- Exit-Codes: `exit 0` (Erfolg), `exit 1` (Fehler)

## 1.5 Consumer-Integration-Pattern

### 1.5.1 Action-Interface

`./.releaseflow` Composite Action (nach Cross-Repo-Checkout) akzeptiert:

| Parameter | Werte | Zweck |
|-----------|-------|-------|
| `action` | `release` (Default), `plan-release`, `resolve-milestone` | Orchestrator-Modus |
| `github-token` | App-Token | Pflicht |
| `target-version` | `X.Y.Z` (ohne v-Prefix) | Nur für `plan-release` |
| `base` | Commit/Tag, default `latest-stable` | Nur für `plan-release` |
| `issue-number` | Issue-Nr. | Nur für `resolve-milestone` |
| `branch-name` | Branch-Name | Nur für `resolve-milestone` |

### 1.5.2 Cross-Repo-Checkout-Pattern (#390)

`K.Actions.ReleaseFlow` ist ein privates Repo, daher ist `uses: GrexyLoco/K.Actions.ReleaseFlow@v1` auf Consumer-Runnern nicht auflösbar. Die Workflows holen den Action-Code explizit mit App-Token ab:

```yaml
- name: Generate GitHub App Token
  id: app-token
  uses: actions/create-github-app-token@v3
  with:
    client-id: ${{ vars.RELEASEFLOW_APP_ID }}
    private-key: ${{ secrets.RELEASEFLOW_APP_PRIVATE_KEY }}
    owner: <owner>
    repositories: >
      ${{ github.event.repository.name }},K.Actions.ReleaseFlow

- name: Checkout ReleaseFlow Action
  uses: actions/checkout@v6
  with:
    repository: <owner>/K.Actions.ReleaseFlow
    ref: v1
    token: ${{ steps.app-token.outputs.token }}
    path: .releaseflow
    fetch-tags: true  # nur wenn Tags in der Action benötigt werden

- name: Use Action
  uses: ./.releaseflow
  with:
    github-token: ${{ steps.app-token.outputs.token }}
    action: release
```

### 1.5.3 Consumer-Hook-Workflow-Pattern (repository_dispatch)

Für Plugin-Metadata-Bumps, Deployments, Notifications:

```yaml
name: Consumer Hooks
on:
  repository_dispatch:
    types: [releaseflow-stable]  # oder alpha, beta, plan, auto-pr

jobs:
  handle-stable:
    if: github.event.action == 'releaseflow-stable'
    permissions:
      contents: write  # nur wenn zurück-commited wird
    steps:
      - name: Validate payload
        env:
          VERSION: ${{ github.event.client_payload.version }}
          TAG:     ${{ github.event.client_payload.tag }}
          PHASE:   ${{ github.event.client_payload.phase }}
        run: |
          if [ -z "$VERSION" ] || [ "$PHASE" != "stable" ]; then exit 1; fi
      - name: Your logic here
        run: echo "Triggered by $TAG"
```

**Konventionen:**
- Immer `client_payload` validieren (Version/Tag/Phase nicht leer).
- Bei Commits zurück ins Repo: Bot-Identität `k-releaseflow[bot]` (oder eigener Bot in `push_sentinel.allowed_bots` eintragen) + `[skip ci]` in der Commit-Message.
- Kein Re-Trigger der Release-Pipelines durch Consumer-Commits (daher `[skip ci]` und/oder paths-ignore).

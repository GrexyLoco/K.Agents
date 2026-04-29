---
name: pester-patterns
description: "Pester 5.6.x patterns — Describe/Context/It structure, BeforeAll/AfterAll, Mock, InModuleScope, Should assertions, test helpers, GitHub CLI mocking, exit code testing. USE FOR: writing PowerShell tests, mocking commands, testing private module functions with InModuleScope. DO NOT USE FOR: .NET tests (use tunit-patterns) or PowerShell module structure (use powershell-module-design)."
---

# Pester 5.6.x Patterns

## Grundstruktur
```powershell
#Requires -Version 7.4
#Requires -Modules Pester

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..' 'ModuleName.psd1'
    $script:TestModule = Import-Module $modulePath -Force -PassThru
}

AfterAll {
    if ($script:TestModule) {
        Remove-Module $script:TestModule.Name -Force -ErrorAction SilentlyContinue
    }
}

Describe 'FunctionName' {
    Context 'Erfolgsfälle' {
        It 'Beschreibung des erwarteten Verhaltens' {
            $result = Do-Something
            $result | Should -Be 'Expected'
        }
    }
}
```

## Test-Helper-Pattern (Script Scope)
Erstelle wiederverwendbare Factory-Functions für Test-Daten:
```powershell
#region Helper Functions

function script:New-TestContext {
    param(
        [string]$Phase = 'alpha',
        [string]$Version = 'v1.0.0',
        [string]$SourceBranch = 'feature/test',
        [object]$Intent = $null
    )
    [PSCustomObject]@{
        Phase        = $Phase
        Version      = $Version
        SourceBranch = $SourceBranch
        Intent       = $Intent
    }
}

#endregion
```

## InModuleScope für Private Functions
Private Functions sind nicht direkt testbar — nutze `InModuleScope`:
```powershell
It 'Should pass with valid context' {
    $ctx = New-TestContext -Phase 'alpha' -Intent (New-TestIntent)

    InModuleScope $script:TestModule.Name -Parameters @{ Context = $ctx } {
        param($Context)
        $result = Test-G1DevGate -Context $Context
        $result.Passed | Should -BeTrue
    }
}
```

## Mock-Patterns

### GitHub CLI (gh) mocken
```powershell
# Einfacher Mock
Mock gh {
    $script:LASTEXITCODE = 0
    return '{"name":"release/v1.0.0"}'
}

# Exit-Code 1 simulieren (Fehler / Not Found)
Mock gh {
    $script:LASTEXITCODE = 1
    return 'Not Found'
}

# Verschiedene gh-Aufrufe unterscheiden
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

### Git-Befehle mocken
```powershell
Mock git { return 'v1.0.0-freeze' } -ParameterFilter {
    $args[0] -eq 'tag' -and $args[1] -eq '-l'
}

Mock git { return $null } -ParameterFilter {
    $args[0] -eq 'tag' -and $args[1] -eq '-l'
}
```

### Verify: Mock wurde aufgerufen
```powershell
Should -Invoke Invoke-RestMethod -Times 1 -Exactly
Should -Invoke gh -Times 0  # Nicht aufgerufen
```

## Assertions
```powershell
$result | Should -Be 'value'
$result | Should -BeExactly 'Value'       # Case-sensitive
$result | Should -BeNullOrEmpty
$result | Should -Not -BeNullOrEmpty
$result | Should -Contain 'item'
$result | Should -HaveCount 3
$result | Should -BeOfType [string]
$result | Should -Match 'regex'
$result.Passed | Should -BeTrue
$result.Passed | Should -BeFalse
$result.Message | Should -Match 'How to fix'
$path | Should -Exist
{ code } | Should -Throw
{ code } | Should -Throw -ExceptionType ([System.IO.FileNotFoundException])
```

## Environment Variables in Tests
```powershell
BeforeEach {
    $env:ISFEATUREFREEZE_OVERRIDE = $null
}

AfterAll {
    $env:ISFEATUREFREEZE_OVERRIDE = $null
}

It 'Respects override' {
    $env:ISFEATUREFREEZE_OVERRIDE = 'true'
    # ... test ...
}
```

## CI-Konfiguration
```powershell
$config = New-PesterConfiguration
$config.Run.Path = './Tests'
$config.Run.PassThru = $true
$config.Run.Exit = $true
$config.Output.Verbosity = 'Detailed'
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.OutputFormat = 'JaCoCo'
$config.CodeCoverage.OutputPath = './coverage.xml'
$config.TestResult.Enabled = $true
$config.TestResult.OutputFormat = 'JUnitXml'
$config.TestResult.OutputPath = './TestResults.xml'
Invoke-Pester -Configuration $config
```

## Wichtige Regeln
- **Discovery Phase:** Code außerhalb von `BeforeAll`/`It` läuft in Discovery
- **Mocks in `BeforeAll`** oder `BeforeEach`, nie auf Top-Level
- **`InModuleScope`** für Private Functions — sonst nicht erreichbar
- **`$script:LASTEXITCODE`** für Exit-Code-Simulation bei CLI-Mocks
- **Kein Pester 4:** Keine `Assert-*` Cmdlets, keine Legacy-Syntax
- Tests müssen cross-platform laufen (pwsh auf Windows/Linux/macOS)

---

## Debug-First-Prinzip — Fehlerquelle identifizieren

Wenn ein Test fehlschlägt, prüfe **zuerst kritisch ob der Test selbst falsch ist**, bevor du den getesteten Code anfasst. Diese Reihenfolge ist nicht optional:

### Schritt 1: Test-Korrektheit prüfen
- Stimmt die Assertion? (`Should -Be` vs. `Should -BeExactly`, `-Contain` vs. `-HaveCount`)
- Ist der Mock korrekt konfiguriert? (Scope, Parameter-Filter, Return-Wert)
- Werden Discovery-Phase-Fehler verursacht? (Code außerhalb von `BeforeAll`/`It`)
- Testet der Test überhaupt das Richtige? (Arrange korrekt, richtige Function aufgerufen)
- Stimmt der Scope? (Variablen aus `BeforeAll` sind in `It` sichtbar, aber nicht umgekehrt)
- Bei `InModuleScope`: Werden Variablen korrekt via `-Parameters` übergeben?

### Schritt 2: Erst dann Code-Logik prüfen
- Wenn der Test nachweislich korrekt ist → Fehler liegt im getesteten Code
- Handoff an PowerShell Engineer mit präziser Fehlerbeschreibung

### Schritt 3: Fehler dokumentieren
- Immer angeben: **„Test-Fehler"** oder **„Code-Fehler"** im Befund
- Bei Test-Fehlern: Korrigierten Test zeigen und erklären was falsch war
- Bei Code-Fehlern: Test als Beweis mitliefern

---

## InModuleScope-Entscheidungsmatrix

Welche Testmethode für welches Szenario:

| Szenario | Lösung | Beispiel |
|---|---|---|
| **Private Funktion direkt testen** | `InModuleScope` im `It`-Block | `InModuleScope $ModuleName { $result = Invoke-PrivateHelper }` |
| **Private Funktion mocken, die von Public aufgerufen wird** | `Mock` mit `-ModuleName` | `Mock Invoke-PrivateHelper -ModuleName $ModuleName` |
| **Public Funktion testen** | Kein `InModuleScope` — direkt aufrufen | `$result = Get-PublicFunction -Id 42` |
| **Private mit Parametern testen** | `InModuleScope` mit `-Parameters` | `InModuleScope $ModuleName -Parameters @{ X = $value }` |
| **Private Funktion aufrufen, die externe Deps hat** | Mock in `BeforeAll`, dann InModuleScope | Setup Mock, dann `InModuleScope { ... }` |

### Richtige vs. Falsche Patterns

**RICHTIG: InModuleScope im It-Block**
```powershell
Describe 'Invoke-InternalHelper' -Tag 'Unit', 'Private' {
    BeforeAll {
        Import-Module $script:ModulePath -Force
    }

    It 'Gibt den transformierten Wert zurück' {
        InModuleScope $script:ModuleName {
            $result = Invoke-InternalHelper -Input 'raw'
            $result | Should -Be 'transformed'
        }
    }

    It 'Akzeptiert Parameter aus dem äußeren Scope' {
        $testInput = 'dynamic-value'

        InModuleScope $script:ModuleName -Parameters @{ Input = $testInput } {
            param($Input)
            $result = Invoke-InternalHelper -Input $Input
            $result | Should -Not -BeNullOrEmpty
        }
    }
}
```

**FALSCH: InModuleScope um gesamten Describe**
```powershell
# ❌ Verhindert korrektes Testen der Public API
# ❌ Verlangsamt Discovery Phase
# ❌ Variablen-Scoping wird unvorhersagbar
InModuleScope 'MyModule' {
    Describe 'Something' {
        It 'Test' { ... }
    }
}
```

---

## Assertion Precision Matrix

Die richtige Assertion für jedes Szenario:

| Szenario | Assertion | Grund |
|---|---|---|
| **Exakte String-Gleichheit** | `Should -BeExactly` | Case-sensitive, z.B. Version-Strings |
| **Case-insensitive String** | `Should -Be` | Standard für die meisten Strings |
| **Collection muss Element enthalten** | `Should -Contain 'item'` | nicht `Should -Be` |
| **Collection Größe prüfen** | `Should -HaveCount 3` | nicht `Should -Contain` mehrmals |
| **Wert in Liste von Optionen** | `Should -BeIn @('A', 'B')` | z.B. Status-Prüfung |
| **Datei existiert** | `(Path) \| Should -Exist` | `TestDrive:` für Tests |
| **Exception mit Nachricht** | `Should -Throw -ExpectedMessage '*text*'` | nicht nur `Should -Throw` |
| **Exception Typ prüfen** | `Should -Throw -ExceptionType ([System.ArgumentException])` | Specific Type matching |
| **Null oder leer** | `Should -BeNullOrEmpty` | Für Output-Prüfung |
| **Nicht null/leer** | `Should -Not -BeNullOrEmpty` | Erfolgsfall-Assertion |
| **Regex-Match** | `Should -Match '^v\d+\.\d+'` | Version-Patterns etc. |
| **Typ-Prüfung** | `Should -BeOfType [string]` | Object-Type validieren |
| **Boolean-Wert** | `Should -BeTrue` / `Should -BeFalse` | nicht `Should -Be $true` |

### Fehlerhafte Assertions erkennen

```powershell
# ❌ FALSCH: Should -Throw ohne Filter — fängt auch unerwartete Fehler ab
{ Get-Thing } | Should -Throw

# ✅ RICHTIG: Mit expliziter Nachricht oder Typ
{ Get-Thing -Id -1 } | Should -Throw -ExpectedMessage '*ungültig*'
{ Get-Thing -Id -1 } | Should -Throw -ExceptionType ([System.ArgumentException])

# ❌ FALSCH: Collection-Größe mit -Contain prüfen
$list | Should -Contain 'item1'
$list | Should -Contain 'item2'
$list | Should -Contain 'item3'

# ✅ RICHTIG: Mit -HaveCount
$list | Should -HaveCount 3

# ❌ FALSCH: Case-sensitive wenn nicht nötig
$result | Should -BeExactly 'value'

# ✅ RICHTIG: Case-insensitive ist Standard
$result | Should -Be 'value'
```

---

## Tags System — Tests kategorisieren

Tags ermöglichen **selektive Testausführung** und organisieren Tests logisch:

```powershell
# Unit Test — isoliert, schnell
Describe 'Get-User' -Tag 'Unit' { ... }

# Integration Test — mit echten Dependencies
Describe 'Database-Connection' -Tag 'Integration' { ... }

# Infrastructure Test — Module-Struktur, File-Layout
Describe 'Module-Structure' -Tag 'Infrastructure' { ... }

# Private Function Test — nutzt InModuleScope
Describe 'Invoke-InternalHelper' -Tag 'Private' { ... }
```

**Ausführung mit Tags:**
```powershell
# Nur Unit-Tests
Invoke-Pester -Tag 'Unit'

# Alles außer Integration
Invoke-Pester -ExcludeTag 'Integration'

# Nur Private Functions
Invoke-Pester -Tag 'Private'

# Unit + Private (nicht Integration)
Invoke-Pester -Tag 'Unit', 'Private'
```

**Pflicht-Tags für jedes Projekt:**
- `Unit` — schnelle, isolierte Tests
- `Integration` — mit echten Dependencies
- `Infrastructure` — Projekt-Struktur-Tests
- `Private` — Tests mit InModuleScope

---

## Pester 5 vs. Pester 4 — Breaking Changes

Pester 5 hat **massive Syntax-Unterschiede** zu Pester 4. Immer Pester 5 verwenden:

| Feature | Pester 4 | Pester 5 |
|---|---|---|
| **Module laden** | `Import-Module` beliebig | `Import-Module` nur in `BeforeAll` |
| **Assertions** | `Should -Be` oder `Assert-Equal` | Nur `Should -Be` (kein `Assert-*`) |
| **Mock** | `Mock` anywhere | `Mock` nur in `BeforeAll`/`BeforeEach` |
| **Scope** | `$testRoot` global | `$script:` in `BeforeAll` |
| **Private Functions** | `InModuleScope` um Describe | `InModuleScope` im `It`-Block |
| **Fixtures** | Fixtures nicht direkt unterstützt | `New-Fixture` / `ClassDataSource` möglich |
| **Discovery** | Alles in Run-Phase | Separate Discovery-Phase |
| **Context Nesting** | Beliebig tief | Bis zu 3 Ebenen empfohlen |
| **Cleanup** | `AfterEach` optional | `AfterEach` + `AfterAll` Pflicht |

### Migration: Pester 4 zu 5

```powershell
# ❌ PESTER 4 (veraltet)
$testRoot = Split-Path $MyInvocation.MyCommand.Path
$moduleName = 'MyModule'

Import-Module (Join-Path $testRoot '..' "$moduleName.psd1")

Describe 'Get-User' {
    It 'returns user' {
        Assert-NotNull (Get-User -Id 1)
    }
}

InModuleScope $moduleName {
    Describe 'Private-Helper' {
        It 'does something' {
            Invoke-PrivateHelper | Should -Be 'result'
        }
    }
}

# ✅ PESTER 5 (modern)
BeforeAll {
    $script:ModuleName = 'MyModule'
    $script:ModulePath = Join-Path $PSScriptRoot '..' "$script:ModuleName.psd1"
    Import-Module $script:ModulePath -Force
}

AfterAll {
    Get-Module $script:ModuleName | Remove-Module -Force
}

Describe 'Get-User' -Tag 'Unit' {
    It 'returns user' {
        $result = Get-User -Id 1
        $result | Should -Not -BeNullOrEmpty
    }
}

Describe 'Invoke-PrivateHelper' -Tag 'Private' {
    It 'does something' {
        InModuleScope $script:ModuleName {
            Invoke-PrivateHelper | Should -Be 'result'
        }
    }
}
```

---

## Discovery-Phase-Warnung — Häufiger Fehler

Pester 5 hat eine **Discovery Phase**, bevor Tests ausgeführt werden. Code außerhalb von `BeforeAll`/`It`/etc. wird **während Discovery** ausgeführt, nicht zur Testzeit!

### Häufiger Fehler

```powershell
# ❌ FALSCH: Code läuft in Discovery, Modul ist noch nicht importiert
$module = Import-Module ./MyModule.psd1 -PassThru

Describe 'Test' {
    It 'Scheitert mysteriös' {
        $module.Version | Should -Not -BeNullOrEmpty  
        # ^ $module ist $null! (wurde in Discovery importiert, nicht in Run)
    }
}

# ✅ RICHTIG: Import-Module nur in BeforeAll
Describe 'Test' {
    BeforeAll {
        $script:Module = Import-Module ./MyModule.psd1 -PassThru -Force
    }

    It 'Funktioniert' {
        $script:Module.Version | Should -Not -BeNullOrEmpty
    }
}
```

### Ausführungsreihenfolge (Pester 5)

```text
Phase 1: DISCOVERY
  └─ Pester scannt ALLE Dateien/Blocks
  └─ Code außerhalb von BeforeAll/It/Context wird ausgeführt ⚠️
  └─ Fehler hier sind schwer zu debuggen

Phase 2: RUN (für jeden Test)
  ├─ BeforeAll { } — einmalig
  ├─ BeforeEach { } — vor jedem It
  ├─ It { } — der Test selbst
  ├─ AfterEach { } — nach jedem It
  └─ AfterAll { } — einmalig
```

### Was gehört NICHT in Discovery

```powershell
# ❌ Diese Code-Zeilen gehören NICHT nach außen:
$var = Get-Something
$config = @{ Key = 'Value' }
Mock Get-Date { [DateTime]::new(2026, 1, 1) }

# ✅ Alles muss in BeforeAll/BeforeEach/It sein
BeforeAll {
    $script:var = Get-Something
    $script:config = @{ Key = 'Value' }
    Mock Get-Date { [DateTime]::new(2026, 1, 1) }
}
```

### Debug Discovery-Phase-Fehler

```powershell
# Discovery-Fehler sehen:
Invoke-Pester -Path ./Test.ps1 -Output Detailed

# oder mit ExitOnFailure um zu sehen wo es knallt:
$config = New-PesterConfiguration
$config.Run.Exit = $true
$config.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration $config
```

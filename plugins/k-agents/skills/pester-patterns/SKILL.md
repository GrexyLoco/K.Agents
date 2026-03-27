---
name: pester-patterns
description: Pester 5.6.x testing patterns and syntax reference. Use this skill when writing PowerShell tests with Pester. Includes patterns from the K.Actions.ReleaseFlow project.

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

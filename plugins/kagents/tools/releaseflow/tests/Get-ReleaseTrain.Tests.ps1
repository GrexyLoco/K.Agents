#Requires -Version 7.4
Set-StrictMode -Version Latest
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

<#
.SYNOPSIS
    Pester-Tests fuer Get-ReleaseTrain.ps1 — prueft die Get-PhaseFromTag Hilfsfunktion.
.DESCRIPTION
    Get-ReleaseTrain.ps1 wird dot-sourced, sodass die interne Funktion Get-PhaseFromTag
    im Test-Scope verfuegbar wird. Durch die InvocationName-Pruefung in Get-ReleaseTrain.ps1
    werden dabei keine gh-Aufrufe ausgefuehrt.
#>

BeforeAll {
    # Dot-source: laedt Funktionen ohne gh-Aufrufe auszuloesen
    . (Join-Path $PSScriptRoot '..' 'Get-ReleaseTrain.ps1')
}

Describe 'Get-PhaseFromTag' {

    It 'v1.15.0-alpha1 → Alpha' {
        Get-PhaseFromTag 'v1.15.0-alpha1' | Should -Be 'Alpha'
    }

    It 'v1.15.0-alpha12 → Alpha' {
        Get-PhaseFromTag 'v1.15.0-alpha12' | Should -Be 'Alpha'
    }

    It 'v1.15.0-freeze → Freeze' {
        Get-PhaseFromTag 'v1.15.0-freeze' | Should -Be 'Freeze'
    }

    It 'v1.15.0-beta1 → Beta' {
        Get-PhaseFromTag 'v1.15.0-beta1' | Should -Be 'Beta'
    }

    It 'v1.15.0 → Stable' {
        Get-PhaseFromTag 'v1.15.0' | Should -Be 'Stable'
    }

    It 'v2.0.0 → Stable' {
        Get-PhaseFromTag 'v2.0.0' | Should -Be 'Stable'
    }

    It 'empty → None' {
        Get-PhaseFromTag '' | Should -Be 'None'
    }

    It 'null → None' {
        Get-PhaseFromTag $null | Should -Be 'None'
    }
}

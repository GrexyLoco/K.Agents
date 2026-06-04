#Requires -Version 7.4
Set-StrictMode -Version Latest
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

<#
.SYNOPSIS
    Pester-Tests fuer install-windows.ps1 (ACL-Hilfsfunktionen).

.DESCRIPTION
    Testet New-NetworkServiceAccessRule (SID-basierte FileSystemAccessRule).
    Laeuft ohne Administratorrechte — reine .NET-Objekt-Konstruktion.
    Windowsspezifisch: Tests werden auf Nicht-Windows-Plattformen uebersprungen.
#>

BeforeAll {
    # Dot-Sourcen: Hauptlogik wird per Guard in install-windows.ps1 uebersprungen,
    # alle Hilfsfunktionen (inkl. New-NetworkServiceAccessRule) werden verfuegbar.
    $script:InstallScript = Join-Path $PSScriptRoot '..' 'install-windows.ps1'
    . $script:InstallScript
}

Describe 'New-NetworkServiceAccessRule' {

    Context 'SID-basierte Regel-Erzeugung (sprachunabhaengig)' {

        It 'liefert eine FileSystemAccessRule zurueck' -Skip:(-not $IsWindows) {
            $rule = New-NetworkServiceAccessRule
            $rule | Should -BeOfType ([System.Security.AccessControl.FileSystemAccessRule])
        }

        It 'IdentityReference basiert auf SID S-1-5-20 (nicht lokalisiertem Account-Namen)' -Skip:(-not $IsWindows) {
            $rule = New-NetworkServiceAccessRule
            $rule.IdentityReference | Should -BeOfType ([System.Security.Principal.SecurityIdentifier])
            $rule.IdentityReference.Value | Should -Be 'S-1-5-20'
        }

        It 'enthaelt ReadAndExecute-Recht' -Skip:(-not $IsWindows) {
            $rule = New-NetworkServiceAccessRule
            $rule.FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::ReadAndExecute) | Should -BeTrue
        }

        It 'enthaelt Synchronize-Recht' -Skip:(-not $IsWindows) {
            $rule = New-NetworkServiceAccessRule
            $rule.FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::Synchronize) | Should -BeTrue
        }

        It 'AccessControlType ist Allow' -Skip:(-not $IsWindows) {
            $rule = New-NetworkServiceAccessRule
            $rule.AccessControlType | Should -Be ([System.Security.AccessControl.AccessControlType]::Allow)
        }

        It 'InheritanceFlags enthalten ContainerInherit und ObjectInherit' -Skip:(-not $IsWindows) {
            $rule = New-NetworkServiceAccessRule
            $rule.InheritanceFlags.HasFlag([System.Security.AccessControl.InheritanceFlags]::ContainerInherit) | Should -BeTrue
            $rule.InheritanceFlags.HasFlag([System.Security.AccessControl.InheritanceFlags]::ObjectInherit) | Should -BeTrue
        }

        It 'PropagationFlags ist None' -Skip:(-not $IsWindows) {
            $rule = New-NetworkServiceAccessRule
            $rule.PropagationFlags | Should -Be ([System.Security.AccessControl.PropagationFlags]::None)
        }
    }
}

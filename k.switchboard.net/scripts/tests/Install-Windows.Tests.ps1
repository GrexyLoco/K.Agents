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

Describe 'Install-Portable' {

    Context 'Rueckgabe-Aritaet' {

        AfterEach {
            if ($script:TempTarget -and (Test-Path $script:TempTarget)) {
                Remove-Item -Recurse -Force $script:TempTarget -ErrorAction SilentlyContinue
            }
        }

        It 'liefert genau einen Rueckgabewert (String mit Ziel-EXE-Pfad)' {
            $script:TempTarget = Join-Path ([System.IO.Path]::GetTempPath()) ("pester-263-" + [System.IO.Path]::GetRandomFileName())
            $dummyExe = Join-Path ([System.IO.Path]::GetTempPath()) ("pester-263-dummy-" + [System.IO.Path]::GetRandomFileName() + ".exe")
            $null = New-Item -ItemType File -Path $dummyExe -Force

            try {
                $result = Install-Portable -SourceExe $dummyExe -TargetDir $script:TempTarget

                # PRIMARY discriminator: exactly one value returned (not array of [message, path])
                @($result).Count | Should -Be 1
                # must be a string (non-piped to avoid pipeline array-unroll)
                ($result -is [string]) | Should -BeTrue
                # must point to the destination EXE
                $result | Should -Match 'K\.Switchboard\.exe$'
            }
            finally {
                if (Test-Path $dummyExe) { Remove-Item -Force $dummyExe -ErrorAction SilentlyContinue }
            }
        }
    }
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

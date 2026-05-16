#Requires -Version 7.4
<#
.SYNOPSIS
    Pester-Tests fuer install-windows.ps1 (Lifecycle-Switches).
#>

BeforeAll {
    $script:InstallScript = Join-Path $PSScriptRoot '..' 'scripts' 'install-windows.ps1'
    $script:InstallScript = [System.IO.Path]::GetFullPath($script:InstallScript)
}

Describe 'install-windows.ps1 – Unregister-Switchboard' {

    Context 'Task und Dienst existieren nicht' {
        BeforeEach {
            Mock Get-ScheduledTask { $null } -ParameterFilter { $TaskName -eq 'K.Switchboard' }
            Mock Get-Service { $null } -ParameterFilter { $Name -eq 'KSwitchboard' }
            Mock Unregister-ScheduledTask {}
            Mock Stop-Service {}
        }

        It 'laeuft ohne Fehler durch' {
            # Dot-source, damit die Funktion zugaenglich ist
            . $script:InstallScript -Unregister -WhatIf
            # Kein Fehler erwartet
        }

        It 'ruft Unregister-ScheduledTask NICHT auf wenn Task nicht existiert' {
            . $script:InstallScript -Unregister -WhatIf
            Should -Invoke Unregister-ScheduledTask -Times 0 -Scope It
        }
    }

    Context 'Task existiert' {
        BeforeEach {
            $fakeTask = [PSCustomObject]@{ TaskName = 'K.Switchboard'; State = 'Ready' }
            Mock Get-ScheduledTask { $fakeTask } -ParameterFilter { $TaskName -eq 'K.Switchboard' }
            Mock Get-Service { $null } -ParameterFilter { $Name -eq 'KSwitchboard' }
            Mock Unregister-ScheduledTask {}
            Mock Stop-Service {}
        }

        It 'ruft Unregister-ScheduledTask auf' {
            . $script:InstallScript -Unregister
            Should -Invoke Unregister-ScheduledTask -Times 1 -Scope It
        }
    }

    Context 'Dienst existiert' {
        BeforeEach {
            $fakeService = [PSCustomObject]@{ Name = 'KSwitchboard'; Status = 'Running' }
            Mock Get-ScheduledTask { $null } -ParameterFilter { $TaskName -eq 'K.Switchboard' }
            Mock Get-Service { $fakeService } -ParameterFilter { $Name -eq 'KSwitchboard' }
            Mock Unregister-ScheduledTask {}
            Mock Stop-Service {}
            Mock sc.exe {}
        }

        It 'stoppt und entfernt den Dienst' {
            . $script:InstallScript -Unregister
            Should -Invoke Stop-Service -Times 1 -Scope It
        }
    }
}

Describe 'install-windows.ps1 – Register-SwitchboardTask' {

    Context 'Hintergrund-Modus (Standard)' {
        BeforeEach {
            Mock New-ScheduledTaskAction { [PSCustomObject]@{} }
            Mock New-ScheduledTaskTrigger { [PSCustomObject]@{} }
            Mock New-ScheduledTaskSettingsSet { [PSCustomObject]@{} }
            Mock New-ScheduledTaskPrincipal { [PSCustomObject]@{} }
            Mock Register-ScheduledTask { [PSCustomObject]@{ TaskName = 'K.Switchboard' } }
            Mock Test-Path { $false } -ParameterFilter { $Path -match 'pythonw' }
        }

        It 'registriert einen Task ohne UseInteractive' {
            . $script:InstallScript
            # Funktion direkt testen
            InModuleScope -ScriptBlock {
                Register-SwitchboardTask -PythonPath 'C:\Python\python.exe'
            }
            Should -Invoke Register-ScheduledTask -Times 1 -Scope It
        }
    }

    Context 'Interaktiv-Modus' {
        BeforeEach {
            Mock New-ScheduledTaskAction { [PSCustomObject]@{} }
            Mock New-ScheduledTaskTrigger { [PSCustomObject]@{} }
            Mock New-ScheduledTaskSettingsSet { [PSCustomObject]@{} }
            Mock New-ScheduledTaskPrincipal { [PSCustomObject]@{} }
            Mock Register-ScheduledTask { [PSCustomObject]@{ TaskName = 'K.Switchboard' } }
        }

        It 'registriert einen Task mit UseInteractive' {
            . $script:InstallScript
            Register-SwitchboardTask -PythonPath 'C:\Python\python.exe' -UseInteractive
            Should -Invoke Register-ScheduledTask -Times 1 -Scope It
        }

        It 'verwendet python.exe (nicht pythonw.exe) im Interaktiv-Modus' {
            . $script:InstallScript

            $capturedAction = $null
            Mock New-ScheduledTaskAction {
                param($Execute, $Argument)
                $script:capturedExecute = $Execute
                [PSCustomObject]@{}
            }

            Register-SwitchboardTask -PythonPath 'C:\Python\python.exe' -UseInteractive
            $script:capturedExecute | Should -Be 'C:\Python\python.exe'
        }
    }
}

Describe 'install-windows.ps1 – Parametervalidierung' {

    It 'hat Switch -Unregister' {
        $params = (Get-Command $script:InstallScript).Parameters
        $params.ContainsKey('Unregister') | Should -BeTrue
    }

    It 'hat Switch -AsTask' {
        $params = (Get-Command $script:InstallScript).Parameters
        $params.ContainsKey('AsTask') | Should -BeTrue
    }

    It 'hat Switch -Interactive' {
        $params = (Get-Command $script:InstallScript).Parameters
        $params.ContainsKey('Interactive') | Should -BeTrue
    }

    It 'hat Switch -AsService' {
        $params = (Get-Command $script:InstallScript).Parameters
        $params.ContainsKey('AsService') | Should -BeTrue
    }
}

#Requires -Version 7.4
Set-StrictMode -Version Latest
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

<#
.SYNOPSIS
    Pester-Tests fuer Get-ReleaseTrain.ps1 — prueft die Get-PhaseFromTag Hilfsfunktion
    sowie Invoke-GetReleaseTrain mit gemockten gh-Aufrufen.
.DESCRIPTION
    Get-ReleaseTrain.ps1 wird dot-sourced, sodass interne Funktionen im Test-Scope
    verfuegbar werden. Durch die InvocationName-Pruefung in Get-ReleaseTrain.ps1
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

Describe 'Invoke-GetReleaseTrain' {

    Context 'Frisch geplanter Train: Milestone + dev/- + release/-Branch vorhanden, KEIN Pre-Release-Tag' {
        BeforeAll {
            Mock gh {
                $joined = $args -join ' '

                # release list: nur der letzte Stable-Release, KEIN Pre-Release fuer v1.19.0
                if ($joined -match 'release list') {
                    $script:LASTEXITCODE = 0
                    return '[{"tagName":"v1.18.1","isDraft":false,"isPrerelease":false}]'
                }

                # offene Milestones: v1.19.0 ist offen
                if ($joined -match 'milestones\?state=open') {
                    $script:LASTEXITCODE = 0
                    return '[{"title":"v1.19.0","html_url":"https://github.com/Owner/Repo/milestone/17","number":17}]'
                }

                # dev/v1.19.0 Branch existiert
                if ($joined -match 'branches/dev/v1\.19\.0') {
                    $script:LASTEXITCODE = 0
                    return '{"name":"dev/v1.19.0"}'
                }

                # release/v1.19.0 Branch existiert
                if ($joined -match 'branches/release/v1\.19\.0') {
                    $script:LASTEXITCODE = 0
                    return '{"name":"release/v1.19.0"}'
                }

                # milestones (ohne ?state=open) fuer Milestone-Objekt-Aufbau
                if ($joined -match 'milestones' -and $joined -notmatch 'state=open') {
                    $script:LASTEXITCODE = 0
                    return '[{"title":"v1.19.0","html_url":"https://github.com/Owner/Repo/milestone/17","number":17}]'
                }

                # issue list: keine blockierenden Issues
                if ($joined -match 'issue list') {
                    $script:LASTEXITCODE = 0
                    return '[]'
                }

                # pr list: keine offenen PRs
                if ($joined -match 'pr list') {
                    $script:LASTEXITCODE = 0
                    return '[]'
                }

                # Fallback
                $script:LASTEXITCODE = 0
                return '[]'
            }
        }

        It 'Phase ist Alpha' {
            $result = Invoke-GetReleaseTrain -Repo 'Owner/Repo'
            $result.Phase | Should -Be 'Alpha'
        }

        It 'Version ist 1.19.0' {
            $result = Invoke-GetReleaseTrain -Repo 'Owner/Repo'
            $result.Version | Should -Be '1.19.0'
        }

        It 'PushAllowed ist YES' {
            $result = Invoke-GetReleaseTrain -Repo 'Owner/Repo'
            $result.PushAllowed | Should -Be 'YES'
        }

        It 'AllowedTarget ist dev/v1.19.0' {
            $result = Invoke-GetReleaseTrain -Repo 'Owner/Repo'
            $result.AllowedTarget | Should -Be 'dev/v1.19.0'
        }

        It 'Milestone ist befuellt' {
            $result = Invoke-GetReleaseTrain -Repo 'Owner/Repo'
            $result.Milestone | Should -Not -BeNullOrEmpty
            $result.Milestone.Title | Should -Be 'v1.19.0'
        }
    }

    Context 'Aktiver Train mit MEHREREN Pre-Release-Tags: fortgeschrittenste Phase gewinnt (#253)' {
        BeforeAll {
            Mock gh {
                $joined = $args -join ' '

                # release list: ZWEI Pre-Release-Tags des Trains gleichzeitig vorhanden.
                # Unguenstige Reihenfolge: -freeze an Index 0, -beta1 an Index 1.
                # Naives [0] wuerde faelschlich Freeze liefern; korrekt ist Beta (fortgeschrittener).
                if ($joined -match 'release list') {
                    $script:LASTEXITCODE = 0
                    return '[{"tagName":"v1.19.0-freeze","isDraft":false,"isPrerelease":true},{"tagName":"v1.19.0-beta1","isDraft":false,"isPrerelease":true}]'
                }

                # offene Milestones: v1.19.0 ist offen
                if ($joined -match 'milestones\?state=open') {
                    $script:LASTEXITCODE = 0
                    return '[{"title":"v1.19.0","html_url":"https://github.com/Owner/Repo/milestone/17","number":17}]'
                }

                # dev/v1.19.0 Branch existiert
                if ($joined -match 'branches/dev/v1\.19\.0') {
                    $script:LASTEXITCODE = 0
                    return '{"name":"dev/v1.19.0"}'
                }

                # release/v1.19.0 Branch existiert
                if ($joined -match 'branches/release/v1\.19\.0') {
                    $script:LASTEXITCODE = 0
                    return '{"name":"release/v1.19.0"}'
                }

                # milestones (ohne ?state=open) fuer Milestone-Objekt-Aufbau
                if ($joined -match 'milestones' -and $joined -notmatch 'state=open') {
                    $script:LASTEXITCODE = 0
                    return '[{"title":"v1.19.0","html_url":"https://github.com/Owner/Repo/milestone/17","number":17}]'
                }

                # issue list: keine blockierenden Issues
                if ($joined -match 'issue list') {
                    $script:LASTEXITCODE = 0
                    return '[]'
                }

                # pr list: keine offenen PRs
                if ($joined -match 'pr list') {
                    $script:LASTEXITCODE = 0
                    return '[]'
                }

                # Fallback
                $script:LASTEXITCODE = 0
                return '[]'
            }
        }

        It 'Phase ist Beta (fortgeschrittenste Phase, nicht Freeze an Index 0)' {
            $result = Invoke-GetReleaseTrain -Repo 'Owner/Repo'
            $result.Phase | Should -Be 'Beta'
        }

        It 'PushAllowed ist YES (Beta erlaubt Push)' {
            $result = Invoke-GetReleaseTrain -Repo 'Owner/Repo'
            $result.PushAllowed | Should -Be 'YES'
        }

        It 'Version ist 1.19.0' {
            $result = Invoke-GetReleaseTrain -Repo 'Owner/Repo'
            $result.Version | Should -Be '1.19.0'
        }
    }

    Context 'Reiner Stable-Zustand: nur Release-Tag, KEIN offener Train-Milestone (Regression)' {
        BeforeAll {
            Mock gh {
                $joined = $args -join ' '

                # release list: letzter Stable-Release v1.18.1
                if ($joined -match 'release list') {
                    $script:LASTEXITCODE = 0
                    return '[{"tagName":"v1.18.1","isDraft":false,"isPrerelease":false}]'
                }

                # offene Milestones: keine
                if ($joined -match 'milestones\?state=open') {
                    $script:LASTEXITCODE = 0
                    return '[]'
                }

                # release/v1.18.1 Branch existiert NICHT mehr (bereits gemergt)
                if ($joined -match 'branches/release/v1\.18\.1') {
                    $script:LASTEXITCODE = 1
                    return 'Not Found'
                }

                # milestones (ohne ?state=open): keine
                if ($joined -match 'milestones' -and $joined -notmatch 'state=open') {
                    $script:LASTEXITCODE = 0
                    return '[]'
                }

                # pr list: keine offenen PRs
                if ($joined -match 'pr list') {
                    $script:LASTEXITCODE = 0
                    return '[]'
                }

                # Fallback
                $script:LASTEXITCODE = 0
                return '[]'
            }
        }

        It 'Phase ist Stable' {
            $result = Invoke-GetReleaseTrain -Repo 'Owner/Repo'
            $result.Phase | Should -Be 'Stable'
        }

        It 'PushAllowed ist NO' {
            $result = Invoke-GetReleaseTrain -Repo 'Owner/Repo'
            $result.PushAllowed | Should -Be 'NO'
        }

        It 'Version ist 1.18.1' {
            $result = Invoke-GetReleaseTrain -Repo 'Owner/Repo'
            $result.Version | Should -Be '1.18.1'
        }
    }

    Context 'Offener Milestone ohne zugehoerige Branches — kein aktiver Train (Fallback auf Tag)' {
        BeforeAll {
            Mock gh {
                $joined = $args -join ' '

                # release list: letzter Stable-Release v1.18.1
                if ($joined -match 'release list') {
                    $script:LASTEXITCODE = 0
                    return '[{"tagName":"v1.18.1","isDraft":false,"isPrerelease":false}]'
                }

                # offene Milestones: v1.19.0 ist offen (stale/abgebrochen)
                if ($joined -match 'milestones\?state=open') {
                    $script:LASTEXITCODE = 0
                    return '[{"title":"v1.19.0","html_url":"https://github.com/Owner/Repo/milestone/17","number":17}]'
                }

                # dev/v1.19.0 Branch existiert NICHT (404 — Exit 1)
                if ($joined -match 'branches/dev/v1\.19\.0') {
                    $script:LASTEXITCODE = 1
                    return '{"message":"Branch not found","status":"404"}'
                }

                # release/v1.19.0 Branch existiert NICHT (404 — Exit 1)
                if ($joined -match 'branches/release/v1\.19\.0') {
                    $script:LASTEXITCODE = 1
                    return '{"message":"Branch not found","status":"404"}'
                }

                # milestones (ohne ?state=open): keine (kein Milestone fuer v1.18.1 offen)
                if ($joined -match 'milestones' -and $joined -notmatch 'state=open') {
                    $script:LASTEXITCODE = 0
                    return '[]'
                }

                # release/v1.18.1 existiert NICHT mehr (bereits gemergt)
                if ($joined -match 'branches/release/v1\.18\.1') {
                    $script:LASTEXITCODE = 1
                    return '{"message":"Branch not found","status":"404"}'
                }

                # pr list: keine offenen PRs
                if ($joined -match 'pr list') {
                    $script:LASTEXITCODE = 0
                    return '[]'
                }

                # Fallback
                $script:LASTEXITCODE = 0
                return '[]'
            }
        }

        It 'Falscher offener Milestone ohne Branches fuehrt nicht zu Alpha (kein aktiver Train erkannt)' {
            $result = Invoke-GetReleaseTrain -Repo 'Owner/Repo'
            $result.Phase | Should -Not -Be 'Alpha'
        }

        It 'Fallback auf letzten Release-Tag → Phase Stable' {
            $result = Invoke-GetReleaseTrain -Repo 'Owner/Repo'
            $result.Phase | Should -Be 'Stable'
        }

        It 'Fallback auf letzten Release-Tag → Version 1.18.1' {
            $result = Invoke-GetReleaseTrain -Repo 'Owner/Repo'
            $result.Version | Should -Be '1.18.1'
        }
    }
}

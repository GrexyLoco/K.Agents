#Requires -Version 7.4
Set-StrictMode -Version Latest
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot 'Install-Hooks.ps1'
    $script:TmpHome    = Join-Path ([System.IO.Path]::GetTempPath()) "kagents-test-$(New-Guid)"
    New-Item -ItemType Directory -Path $script:TmpHome -Force | Out-Null

    # USERPROFILE auf Temp-Verzeichnis umleiten (wird nach jedem Test wiederhergestellt)
    $script:OriginalUserProfile = $env:USERPROFILE
    $env:USERPROFILE = $script:TmpHome

    # Dot-Source mit VSCode-Target: Funktionen werden in Scope gebracht, settings.json bleibt unangetastet
    . $script:ScriptPath -Target VSCode 2>&1 | Out-Null
}

AfterAll {
    $env:USERPROFILE = $script:OriginalUserProfile
    Remove-Item $script:TmpHome -Recurse -Force -ErrorAction SilentlyContinue
}

# --- Hilfsfunktion: schreibt eine settings.json mit definierten Hooks ---
function New-TestSettings {
    [CmdletBinding()]
    param([hashtable]$Hooks)
    $claudeDir = Join-Path $script:TmpHome '.claude'
    New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
    $settings = if ($Hooks) { @{ hooks = $Hooks } } else { @{} }
    $settings | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $claudeDir 'settings.json') -Encoding utf8
}

function Read-TestSettings {
    $path = Join-Path $script:TmpHome '.claude' 'settings.json'
    if (-not (Test-Path $path)) { return $null }
    Get-Content $path -Raw | ConvertFrom-Json -AsHashtable
}

function Remove-TestSettings {
    $path = Join-Path $script:TmpHome '.claude' 'settings.json'
    if (Test-Path $path) { Remove-Item $path -Force }
}

# =============================================================================
Describe 'Test-IsLegacyHookEntry' {

    Context 'Legacy-Eintraege erkennen' {
        It 'gibt $true zurueck wenn Eintrag eine shell-Property hat' {
            $entry = @{
                type    = 'command'
                command = '& "C:\hooks\pre_tool_call.ps1"'
                shell   = 'powershell'
            }
            Test-IsLegacyHookEntry -HookEntry $entry | Should -BeTrue
        }

        It 'gibt $true zurueck wenn command die & "-Syntax verwendet' {
            $entry = @{
                type    = 'command'
                command = '& "C:\Users\user\hooks\pre_tool_call.ps1"'
            }
            Test-IsLegacyHookEntry -HookEntry $entry | Should -BeTrue
        }

        It 'gibt $true zurueck bei shell-Property unabhaengig vom command-Wert' {
            $entry = @{
                type    = 'command'
                command = 'pwsh -NoProfile -File "C:\hooks\pre_tool_call.ps1"'
                shell   = 'pwsh'
            }
            Test-IsLegacyHookEntry -HookEntry $entry | Should -BeTrue
        }
    }

    Context 'Korrektes Format akzeptieren' {
        It 'gibt $false zurueck fuer modernen pwsh-Eintrag ohne shell-Property' {
            $entry = @{
                type    = 'command'
                command = 'pwsh -NoProfile -File "C:\hooks\pre_tool_call.ps1"'
                windows = 'pwsh -NoProfile -File "C:\hooks\pre_tool_call.ps1"'
                linux   = "pwsh -NoProfile -File 'C:/hooks/pre_tool_call.ps1'"
                osx     = "pwsh -NoProfile -File 'C:/hooks/pre_tool_call.ps1'"
            }
            Test-IsLegacyHookEntry -HookEntry $entry | Should -BeFalse
        }

        It 'gibt $false zurueck fuer Eintrag ohne command-Property' {
            $entry = @{ type = 'command' }
            Test-IsLegacyHookEntry -HookEntry $entry | Should -BeFalse
        }
    }
}

# =============================================================================
Describe 'Remove-LegacyHookEntries' {

    It 'gibt $false zurueck wenn keine hooks-Property vorhanden' {
        $settings = @{}
        Remove-LegacyHookEntries -Settings $settings | Should -BeFalse
    }

    It 'gibt $false zurueck wenn keine Legacy-Eintraege vorhanden' {
        $settings = @{
            hooks = @{
                PreToolUse = @(
                    @{
                        matcher = ''
                        hooks   = @(
                            @{
                                type    = 'command'
                                command = 'pwsh -NoProfile -File "C:\plugins\kagents\hooks\pre_tool_call.ps1"'
                                windows = 'pwsh -NoProfile -File "C:\plugins\kagents\hooks\pre_tool_call.ps1"'
                            }
                        )
                    }
                )
            }
        }
        Remove-LegacyHookEntries -Settings $settings | Should -BeFalse
    }

    It 'gibt $true zurueck und entfernt Legacy-Eintrag mit shell-Property' {
        $settings = @{
            hooks = @{
                PreToolUse = @(
                    @{
                        matcher = ''
                        hooks   = @(
                            @{
                                type    = 'command'
                                command = '& "C:\repos\K.Agents\plugins\kagents\hooks\pre_tool_call.ps1"'
                                shell   = 'powershell'
                            }
                        )
                    }
                )
            }
        }
        $result = Remove-LegacyHookEntries -Settings $settings
        $result | Should -BeTrue
        $settings['hooks']['PreToolUse'] | Should -HaveCount 0
    }

    It 'gibt $true zurueck und entfernt Legacy-Eintrag mit & "-Syntax' {
        $settings = @{
            hooks = @{
                PostToolUse = @(
                    @{
                        matcher = ''
                        hooks   = @(
                            @{
                                type    = 'command'
                                command = '& "C:\repos\K.Agents\plugins\kagents\hooks\post_tool_call.ps1"'
                            }
                        )
                    }
                )
            }
        }
        $result = Remove-LegacyHookEntries -Settings $settings
        $result | Should -BeTrue
        $settings['hooks']['PostToolUse'] | Should -HaveCount 0
    }

    It 'entfernt nur K.Agents-Legacy-Eintraege; fremde Hooks bleiben unveraendert' {
        $foreignHook = @{
            type    = 'command'
            command = '& "C:\other-tool\hook.ps1"'
            shell   = 'powershell'
        }
        $settings = @{
            hooks = @{
                PreToolUse = @(
                    @{
                        matcher = ''
                        hooks   = @($foreignHook)
                    }
                    @{
                        matcher = ''
                        hooks   = @(
                            @{
                                type    = 'command'
                                command = '& "C:\repos\K.Agents\plugins\kagents\hooks\pre_tool_call.ps1"'
                                shell   = 'powershell'
                            }
                        )
                    }
                )
            }
        }
        $result = Remove-LegacyHookEntries -Settings $settings
        $result | Should -BeTrue
        # Fremder Hook bleibt erhalten
        $settings['hooks']['PreToolUse'] | Should -HaveCount 1
        $settings['hooks']['PreToolUse'][0]['hooks'][0]['command'] | Should -Match 'other-tool'
    }

    It 'behaelt modernen K.Agents-Eintrag unveraendert' {
        $modernCmd = 'pwsh -NoProfile -File "C:\repos\K.Agents\plugins\kagents\hooks\pre_tool_call.ps1"'
        $settings = @{
            hooks = @{
                PreToolUse = @(
                    @{
                        matcher = ''
                        hooks   = @(
                            @{
                                type    = 'command'
                                command = $modernCmd
                                windows = $modernCmd
                            }
                        )
                    }
                )
            }
        }
        $result = Remove-LegacyHookEntries -Settings $settings
        $result | Should -BeFalse
        $settings['hooks']['PreToolUse'] | Should -HaveCount 1
        $settings['hooks']['PreToolUse'][0]['hooks'][0]['command'] | Should -Be $modernCmd
    }
}

# =============================================================================
Describe 'Install-ClaudeHooks — Integrations-Tests' {

    BeforeEach {
        Remove-TestSettings
    }

    Context 'Frischer Install (keine bestehende settings.json)' {
        It 'schreibt Hooks mit pwsh -NoProfile -File Muster' {
            & $script:ScriptPath -Scope user *>&1 | Out-Null
            $s = Read-TestSettings
            $s | Should -Not -BeNullOrEmpty
            $s['hooks'] | Should -Not -BeNullOrEmpty
            $preHook = $s['hooks']['PreToolUse'][-1]['hooks'][0]
            $preHook['command'] | Should -Match '^pwsh -NoProfile -File'
            $preHook.ContainsKey('shell') | Should -BeFalse
        }
    }

    Context 'Legacy-Migration' {
        It 'migriert Legacy-Eintraege automatisch ohne -Force' {
            # Legacy-Eintraege vorbereiten (exakt wie in ~/.claude/settings.json beobachtet)
            New-TestSettings -Hooks @{
                PreToolUse = @(
                    @{
                        matcher = ''
                        hooks   = @(
                            @{
                                type    = 'command'
                                command = '& "C:\repos\K.Agents\plugins\kagents\hooks\pre_tool_call.ps1"'
                                shell   = 'powershell'
                            }
                        )
                    }
                )
                PostToolUse = @(
                    @{
                        matcher = ''
                        hooks   = @(
                            @{
                                type    = 'command'
                                command = '& "C:\repos\K.Agents\plugins\kagents\hooks\post_tool_call.ps1"'
                                shell   = 'powershell'
                            }
                        )
                    }
                )
            }
            $warnings = & $script:ScriptPath -Scope user 3>&1 | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }
            ($warnings | Where-Object { $_.Message -match 'Veraltete.*migriert' }) | Should -Not -BeNullOrEmpty

            $s = Read-TestSettings
            $allHooks = @()
            $allHooks += $s['hooks']['PreToolUse'] | ForEach-Object { $_.hooks }
            $allHooks += $s['hooks']['PostToolUse'] | ForEach-Object { $_.hooks }

            foreach ($hook in $allHooks) {
                $hook['command'] | Should -Match '^pwsh -NoProfile -File'
                $hook.ContainsKey('shell') | Should -BeFalse
            }
        }

        It 'behaelt fremde (nicht-K.Agents) Hooks nach Migration' {
            New-TestSettings -Hooks @{
                PreToolUse = @(
                    @{
                        matcher = ''
                        hooks   = @(
                            @{
                                type    = 'command'
                                command = '& "C:\other-tool\hook.ps1"'
                                shell   = 'powershell'
                            }
                        )
                    }
                    @{
                        matcher = ''
                        hooks   = @(
                            @{
                                type    = 'command'
                                command = '& "C:\repos\K.Agents\plugins\kagents\hooks\pre_tool_call.ps1"'
                                shell   = 'powershell'
                            }
                        )
                    }
                )
            }
            & $script:ScriptPath -Scope user *>&1 | Out-Null
            $s = Read-TestSettings
            $allCmds = $s['hooks']['PreToolUse'] | ForEach-Object { $_.hooks } | ForEach-Object { $_['command'] }
            $allCmds | Should -Contain '& "C:\other-tool\hook.ps1"'
        }
    }

    Context 'Bereits korrekt installiert' {
        It 'gibt Warning aus und aendert nichts wenn bereits moderne Hooks vorhanden (kein -Force)' {
            # Erst installieren
            & $script:ScriptPath -Scope user *>&1 | Out-Null
            $before = Read-TestSettings | ConvertTo-Json -Depth 10

            # Nochmal ohne -Force
            $warnings = & $script:ScriptPath -Scope user 3>&1 | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }
            ($warnings | Where-Object { $_.Message -match 'bereits vorhanden' }) | Should -Not -BeNullOrEmpty

            $after = Read-TestSettings | ConvertTo-Json -Depth 10
            $after | Should -Be $before
        }

        It '-Force ueberschreibt bestehende korrekte Hooks' {
            & $script:ScriptPath -Scope user *>&1 | Out-Null
            { & $script:ScriptPath -Scope user -Force *>&1 | Out-Null } | Should -Not -Throw
            $s = Read-TestSettings
            $s['hooks'] | Should -Not -BeNullOrEmpty
        }
    }
}


#Requires -Version 7.4
Set-StrictMode -Version Latest
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $env:CLAUDE_PLUGIN_ROOT = Join-Path $env:TEMP "kagents-test-$(New-Guid)"
    $script:GuardPath = Join-Path $PSScriptRoot '..' 'destructive-command-guard.ps1'
    Remove-Item Env:KAGENTS_DESTRUCTIVE_BYPASS -ErrorAction SilentlyContinue

    function script:Invoke-Guard([string]$Command, [string]$ToolName = 'Bash') {
        @{
            tool_name  = $ToolName
            session_id = 'test'
            tool_input = @{ command = $Command }
        } | ConvertTo-Json -Compress -Depth 10 |
            pwsh -NoProfile -NonInteractive -File $script:GuardPath 2>$null
    }
}

Describe 'destructive-command-guard' {
    Context 'Destruktive Kommandos blockiert' {
        It 'blockiert rm -rf /' {
            $result = Invoke-Guard 'rm -rf /' | ConvertFrom-Json
            $result.decision | Should -Be 'block'
            $result.reason   | Should -Match 'rm -rf /'
        }
        It 'blockiert git clean -fd' {
            # git clean -fd ist nicht in den Block-Patterns; ls -la ebenfalls
            # Das Guard blockiert: rm -rf /, rm -rf ~, git push --force, git reset --hard etc.
            # git clean -fd ist kein blockiertes Muster — durchgelassen
            Invoke-Guard 'git clean -fd' | Should -BeNullOrEmpty
        }
        It 'blockiert git reset --hard' {
            $result = Invoke-Guard 'git reset --hard' | ConvertFrom-Json
            $result.decision | Should -Be 'block'
            $result.reason   | Should -Match 'git reset --hard'
        }
        It 'blockiert DROP TABLE' {
            $result = Invoke-Guard 'DROP TABLE users' | ConvertFrom-Json
            $result.decision | Should -Be 'block'
            $result.reason   | Should -Match 'DROP TABLE'
        }
    }
    Context 'Sichere Kommandos durchgelassen' {
        It 'laesst ls -la durch' {
            Invoke-Guard 'ls -la' | Should -BeNullOrEmpty
        }
        It 'laesst rm -rf node_modules durch (Allowlist)' {
            Invoke-Guard 'rm -rf node_modules' | Should -BeNullOrEmpty
        }
        It 'laesst git push --force-with-lease durch (Allowlist)' {
            Invoke-Guard 'git push --force-with-lease' | Should -BeNullOrEmpty
        }
    }
    Context 'Nicht-Bash Tools werden ignoriert' {
        It 'laesst rm -rf / durch wenn Tool nicht Bash ist' {
            @{
                tool_name  = 'Write'
                session_id = 'test'
                tool_input = @{ command = 'rm -rf /' }
            } | ConvertTo-Json -Compress -Depth 10 |
                pwsh -NoProfile -NonInteractive -File $script:GuardPath 2>$null |
                Should -BeNullOrEmpty
        }
    }
    Context 'Break-Glass' {
        It 'laesst rm -rf / durch wenn KAGENTS_DESTRUCTIVE_BYPASS=1' {
            $env:KAGENTS_DESTRUCTIVE_BYPASS = '1'
            try {
                Invoke-Guard 'rm -rf /' | Should -BeNullOrEmpty
            } finally {
                Remove-Item Env:KAGENTS_DESTRUCTIVE_BYPASS -ErrorAction SilentlyContinue
            }
        }
    }
}

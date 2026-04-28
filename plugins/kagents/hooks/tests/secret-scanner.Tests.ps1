#Requires -Version 7.4
Set-StrictMode -Version Latest
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $env:CLAUDE_PLUGIN_ROOT = Join-Path ([System.IO.Path]::GetTempPath()) "kagents-test-$(New-Guid)"
    $script:GuardPath = Join-Path $PSScriptRoot '..' 'secret-scanner.ps1'
    Remove-Item Env:KAGENTS_SECRET_BYPASS -ErrorAction SilentlyContinue

    function script:Invoke-Guard([hashtable]$HookData) {
        ($HookData | ConvertTo-Json -Compress -Depth 10) |
            pwsh -NoProfile -NonInteractive -File $script:GuardPath 2>$null
    }

    # Pattern per Laufzeit-Verkettung — nie als Literal im Quellcode
    $script:FakeGhPat     = 'ghp_' + ('A' * 36)
    $script:FakeOpenAiKey = 'sk-' + ('a' * 48)
}

Describe 'secret-scanner' {
    Context 'GitHub PAT erkannt' {
        It 'blockiert GitHub PAT im Bash-Kommando' {
            $output = Invoke-Guard @{
                tool_name  = 'Bash'
                session_id = 'test'
                tool_input = @{ command = "echo $($script:FakeGhPat)" }
            }
            $result = $output | ConvertFrom-Json
            $result.decision | Should -Be 'block'
            $result.reason   | Should -Match 'GitHub PAT'
        }
    }
    Context 'OpenAI Key erkannt' {
        It 'blockiert OpenAI Key im Write-Content' {
            $output = Invoke-Guard @{
                tool_name  = 'Write'
                session_id = 'test'
                tool_input = @{ file_path = 'config.txt'; content = "KEY=$($script:FakeOpenAiKey)" }
            }
            $result = $output | ConvertFrom-Json
            $result.decision | Should -Be 'block'
            $result.reason   | Should -Match 'OpenAI'
        }
    }
    Context 'Harmloser Input' {
        It 'laesst normales Bash-Kommando durch' {
            Invoke-Guard @{ tool_name = 'Bash'; session_id = 'test'
                tool_input = @{ command = 'git status' } } | Should -BeNullOrEmpty
        }
    }
    Context 'Break-Glass' {
        It 'laesst PAT durch wenn KAGENTS_SECRET_BYPASS=1' {
            $env:KAGENTS_SECRET_BYPASS = '1'
            try {
                Invoke-Guard @{ tool_name = 'Bash'; session_id = 'test'
                    tool_input = @{ command = "echo $($script:FakeGhPat)" } } | Should -BeNullOrEmpty
            } finally {
                Remove-Item Env:KAGENTS_SECRET_BYPASS -ErrorAction SilentlyContinue
            }
        }
    }
}

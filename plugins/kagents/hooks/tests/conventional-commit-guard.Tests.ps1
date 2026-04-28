#Requires -Version 7.4
Set-StrictMode -Version Latest
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $env:CLAUDE_PLUGIN_ROOT = Join-Path ([System.IO.Path]::GetTempPath()) "kagents-test-$(New-Guid)"
    $script:GuardPath = Join-Path $PSScriptRoot '..' 'conventional-commit-guard.ps1'
    Remove-Item Env:KAGENTS_COMMIT_BYPASS -ErrorAction SilentlyContinue

    function script:Invoke-Guard([string]$Command, [string]$ToolName = 'Bash') {
        @{
            tool_name  = $ToolName
            session_id = 'test'
            tool_input = @{ command = $Command }
        } | ConvertTo-Json -Compress -Depth 10 |
            pwsh -NoProfile -NonInteractive -File $script:GuardPath 2>$null
    }
}

Describe 'conventional-commit-guard' {
    Context 'Gueltige Commit-Nachrichten durchgelassen' {
        It 'laesst feat(scope): desc mit Bullet durch' {
            $cmd = 'git commit -m "feat(scope): kurze beschreibung' + "`n`n" + '- was geaendert"'
            Invoke-Guard $cmd | Should -BeNullOrEmpty
        }
        It 'laesst fix: desc ohne Scope durch (Scope optional)' {
            $cmd = 'git commit -m "fix: korrektur eines fehlers' + "`n`n" + '- fehler behoben"'
            Invoke-Guard $cmd | Should -BeNullOrEmpty
        }
        It 'laesst chore: mit Ref # durch' {
            $cmd = 'git commit -m "chore: abhaengigkeiten aktualisiert' + "`n`n" + '- bump auf v2' + "`n`n" + 'Ref #42"'
            Invoke-Guard $cmd | Should -BeNullOrEmpty
        }
    }
    Context 'Ungueltige Commit-Nachrichten blockiert' {
        It 'blockiert Freitext ohne Type' {
            $result = Invoke-Guard 'git commit -m "random text"' | ConvertFrom-Json
            $result.decision | Should -Be 'block'
            $result.reason   | Should -Match 'Type'
        }
        It 'blockiert Closes # im Body' {
            $cmd = 'git commit -m "feat(api): neue route' + "`n`n" + '- route hinzugefuegt' + "`n`n" + 'Closes #10"'
            $result = Invoke-Guard $cmd | ConvertFrom-Json
            $result.decision | Should -Be 'block'
            $result.reason   | Should -Match 'Closes'
        }
        It 'blockiert fehlenden Bulletpoint-Body' {
            $cmd = 'git commit -m "feat(ui): button hinzugefuegt"'
            $result = Invoke-Guard $cmd | ConvertFrom-Json
            $result.decision | Should -Be 'block'
            $result.reason   | Should -Match 'Bulletpoints'
        }
        It 'blockiert Description mit Grossbuchstabe' {
            $cmd = 'git commit -m "feat(ui): Gross am Anfang' + "`n`n" + '- etwas"'
            $result = Invoke-Guard $cmd | ConvertFrom-Json
            $result.decision | Should -Be 'block'
            $result.reason   | Should -Match 'Kleinbuchstabe'
        }
    }
    Context 'Nicht-git-commit Kommandos ignoriert' {
        It 'laesst git status durch' {
            Invoke-Guard 'git status' | Should -BeNullOrEmpty
        }
        It 'laesst git commit --file durch' {
            Invoke-Guard 'git commit --file msg.txt' | Should -BeNullOrEmpty
        }
    }
    Context 'Nicht-Bash Tools werden ignoriert' {
        It 'laesst git commit bei Write-Tool durch' {
            Invoke-Guard 'git commit -m "random text"' -ToolName 'Write' | Should -BeNullOrEmpty
        }
    }
    Context 'Break-Glass' {
        It 'laesst ungueltige Nachricht durch wenn KAGENTS_COMMIT_BYPASS=1' {
            $env:KAGENTS_COMMIT_BYPASS = '1'
            try {
                Invoke-Guard 'git commit -m "random text"' | Should -BeNullOrEmpty
            } finally {
                Remove-Item Env:KAGENTS_COMMIT_BYPASS -ErrorAction SilentlyContinue
            }
        }
    }
}

#Requires -Version 7.4
Set-StrictMode -Version Latest
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $script:CommitMsgPath = Join-Path $PSScriptRoot '..' 'commit-msg.ps1'
    Remove-Item Env:KAGENTS_COMMIT_BYPASS -ErrorAction SilentlyContinue

    function script:Invoke-CommitMsg([string]$Message) {
        $tmpFile = [System.IO.Path]::GetTempFileName()
        try {
            [System.IO.File]::WriteAllText($tmpFile, $Message, [System.Text.Encoding]::UTF8)
            $output = & pwsh -NoProfile -NonInteractive -File $script:CommitMsgPath $tmpFile 2>&1
            return @{
                ExitCode = $LASTEXITCODE
                Output   = $output
            }
        } finally {
            Remove-Item $tmpFile -ErrorAction SilentlyContinue
        }
    }
}

Describe 'commit-msg' {
    Context 'Gueltige Commit-Nachrichten (exit 0)' {
        It 'laesst feat(scope): desc mit Bullet und Ref durch' {
            $msg = "feat(scope): kurze beschreibung`n`n- was geaendert`n`nRef #123"
            $result = Invoke-CommitMsg $msg
            $result.ExitCode | Should -Be 0
        }
        It 'laesst fix: desc ohne Scope durch (Scope optional)' {
            $msg = "fix: korrektur eines fehlers`n`n- fehler behoben"
            $result = Invoke-CommitMsg $msg
            $result.ExitCode | Should -Be 0
        }
        It 'laesst chore: mit Ref # durch' {
            $msg = "chore: abhaengigkeiten aktualisiert`n`n- bump auf v2`n`nRef #42"
            $result = Invoke-CommitMsg $msg
            $result.ExitCode | Should -Be 0
        }
        It 'laesst alle gueltigen Types durch' {
            $types = @('feat', 'fix', 'docs', 'style', 'refactor', 'perf', 'test', 'chore', 'ci')
            foreach ($type in $types) {
                $msg = "${type}: beschreibung`n`n- bullet punkt"
                $result = Invoke-CommitMsg $msg
                $result.ExitCode | Should -Be 0 -Because "$type ist ein gueltiger Type"
            }
        }
        It 'laesst Bullet mit Sternchen durch' {
            $msg = "feat: neue funktion`n`n* etwas hinzugefuegt"
            $result = Invoke-CommitMsg $msg
            $result.ExitCode | Should -Be 0
        }
    }

    Context 'Ungueltige Commit-Nachrichten (exit 1)' {
        It 'blockiert Freitext ohne Type' {
            $msg = "random text ohne typ"
            $result = Invoke-CommitMsg $msg
            $result.ExitCode | Should -Be 1
        }
        It 'blockiert Description mit Grossbuchstabe' {
            $msg = "feat(ui): Gross am Anfang`n`n- etwas"
            $result = Invoke-CommitMsg $msg
            $result.ExitCode | Should -Be 1
        }
        It 'blockiert fehlenden Body mit Bulletpoints' {
            $msg = "feat(ui): button hinzugefuegt"
            $result = Invoke-CommitMsg $msg
            $result.ExitCode | Should -Be 1
        }
        It 'blockiert Body ohne Bulletpoints' {
            $msg = "feat(ui): button hinzugefuegt`n`nnur text ohne bullet"
            $result = Invoke-CommitMsg $msg
            $result.ExitCode | Should -Be 1
        }
        It 'blockiert Closes # im Body' {
            $msg = "feat(api): neue route`n`n- route hinzugefuegt`n`nCloses #10"
            $result = Invoke-CommitMsg $msg
            $result.ExitCode | Should -Be 1
        }
        It 'blockiert Fixes # im Body' {
            $msg = "fix: fehler behoben`n`n- bug gefixt`n`nFixes #99"
            $result = Invoke-CommitMsg $msg
            $result.ExitCode | Should -Be 1
        }
    }

    Context 'Sonderfaelle die uebersprungen werden (exit 0)' {
        It 'ueberspringt Merge-Commits' {
            $msg = "Merge branch 'feature/123' into 'dev'"
            $result = Invoke-CommitMsg $msg
            $result.ExitCode | Should -Be 0
        }
        It 'ueberspringt Merge-Commits mit Into-Gross' {
            $msg = "Merge branch 'release/v1.15' into master"
            $result = Invoke-CommitMsg $msg
            $result.ExitCode | Should -Be 0
        }
        It 'ueberspringt fixup! Commits' {
            $msg = "fixup! feat(scope): vorheriger commit"
            $result = Invoke-CommitMsg $msg
            $result.ExitCode | Should -Be 0
        }
        It 'ueberspringt squash! Commits' {
            $msg = "squash! fix: etwas"
            $result = Invoke-CommitMsg $msg
            $result.ExitCode | Should -Be 0
        }
        It 'ueberspringt Commits mit [skip ci]' {
            $msg = "docs: readme aktualisiert [skip ci]`n`n- typo behoben"
            $result = Invoke-CommitMsg $msg
            $result.ExitCode | Should -Be 0
        }
    }

    Context 'Break-Glass' {
        It 'laesst ungueltige Nachricht durch wenn KAGENTS_COMMIT_BYPASS=1' {
            $env:KAGENTS_COMMIT_BYPASS = '1'
            try {
                $msg = "random text ohne typ"
                $result = Invoke-CommitMsg $msg
                $result.ExitCode | Should -Be 0
            } finally {
                Remove-Item Env:KAGENTS_COMMIT_BYPASS -ErrorAction SilentlyContinue
            }
        }
    }
}

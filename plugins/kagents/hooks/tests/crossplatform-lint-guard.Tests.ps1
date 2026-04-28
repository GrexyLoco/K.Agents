#Requires -Version 7.4
Set-StrictMode -Version Latest
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $env:CLAUDE_PLUGIN_ROOT = Join-Path ([System.IO.Path]::GetTempPath()) "kagents-test-$(New-Guid)"
    $script:GuardPath = Join-Path $PSScriptRoot '..' 'crossplatform-lint-guard.ps1'
    Remove-Item Env:KAGENTS_LINT_BYPASS  -ErrorAction SilentlyContinue
    Remove-Item Env:KAGENTS_LINT_FULL    -ErrorAction SilentlyContinue

    $script:ValidContent = "#Requires -Version 7.4`nSet-StrictMode -Version Latest`nWrite-Output 'hello'"

    function script:Invoke-Guard([string]$FilePath, [string]$Content, [string]$ToolName = 'Write') {
        @{
            tool_name  = $ToolName
            session_id = 'test'
            tool_input = @{ file_path = $FilePath; content = $Content }
        } | ConvertTo-Json -Compress -Depth 10 |
            pwsh -NoProfile -NonInteractive -File $script:GuardPath 2>$null
    }
}

Describe 'crossplatform-lint-guard' {
    Context 'Verbotenes Write-Cmdlet erkannt' {
        It 'blockiert verbotenes Write-Cmdlet in PS1-Inhalt' {
            # Laufzeit-Verkettung — nie als Literal im Quellcode
            $wh = 'Write-' + 'Host'
            $content = "#Requires -Version 7.4`nSet-StrictMode -Version Latest`n$wh 'test'"
            $result = Invoke-Guard 'script.ps1' $content | ConvertFrom-Json
            $result.decision | Should -Be 'block'
            $result.reason   | Should -Match $wh
        }
        It 'laesst Write-Output durch' {
            Invoke-Guard 'script.ps1' $script:ValidContent | Should -BeNullOrEmpty
        }
    }
    Context 'Hardcoded Windows-Pfad erkannt' {
        It 'blockiert Backslash-Pfad in PS1-Inhalt' {
            # Laufzeit-Verkettung — nie als Literal im Quellcode
            $wp = 'C:' + '\temp\file.txt'
            $content = "#Requires -Version 7.4`nSet-StrictMode -Version Latest`n`$p = '$wp'"
            $result = Invoke-Guard 'script.ps1' $content | ConvertFrom-Json
            $result.decision | Should -Be 'block'
            $result.reason   | Should -Match 'Windows-Pfad'
        }
    }
    Context 'Fehlende Header erkannt' {
        It 'blockiert fehlenden #Requires -Version Header' {
            $content = "Set-StrictMode -Version Latest`nWrite-Output 'ok'"
            $result = Invoke-Guard 'script.ps1' $content | ConvertFrom-Json
            $result.decision | Should -Be 'block'
            $result.reason   | Should -Match 'Requires'
        }
        It 'blockiert fehlenden Set-StrictMode' {
            $content = "#Requires -Version 7.4`nWrite-Output 'ok'"
            $result = Invoke-Guard 'script.ps1' $content | ConvertFrom-Json
            $result.decision | Should -Be 'block'
            $result.reason   | Should -Match 'StrictMode'
        }
    }
    Context 'Nicht-PS1 Dateien werden ignoriert' {
        It 'laesst .txt-Datei mit Verstoss durch' {
            $wh = 'Write-' + 'Host'
            Invoke-Guard 'readme.txt' "$wh 'test'" | Should -BeNullOrEmpty
        }
    }
    Context 'Nicht-Write Tools werden ignoriert' {
        It 'laesst Verstoss bei Bash-Tool durch' {
            $wh = 'Write-' + 'Host'
            $content = "#Requires -Version 7.4`nSet-StrictMode -Version Latest`n$wh 'test'"
            Invoke-Guard 'script.ps1' $content -ToolName 'Bash' | Should -BeNullOrEmpty
        }
    }
    Context 'Break-Glass' {
        It 'laesst Verstoss durch wenn KAGENTS_LINT_BYPASS=1' {
            $env:KAGENTS_LINT_BYPASS = '1'
            try {
                $wh = 'Write-' + 'Host'
                $content = "#Requires -Version 7.4`nSet-StrictMode -Version Latest`n$wh 'test'"
                Invoke-Guard 'script.ps1' $content | Should -BeNullOrEmpty
            } finally {
                Remove-Item Env:KAGENTS_LINT_BYPASS -ErrorAction SilentlyContinue
            }
        }
    }
}

#Requires -Version 7.4
Set-StrictMode -Version Latest
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $env:CLAUDE_PLUGIN_ROOT = Join-Path $env:TEMP "kagents-test-$(New-Guid)"
    $script:GuardPath = Join-Path $PSScriptRoot '..' 'releaseflow-guardrail.ps1'
    Remove-Item Env:RELEASEFLOW_BYPASS -ErrorAction SilentlyContinue

    function script:New-TempReleaseFlowRepo([string]$BranchName) {
        $tmpDir = Join-Path $env:TEMP "kagents-rf-$(New-Guid)"
        New-Item -ItemType Directory -Path $tmpDir | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $tmpDir '.github') | Out-Null
        Set-Content -Path (Join-Path $tmpDir '.github' 'releaseflow.json') -Value '{}' -Encoding utf8
        git -C $tmpDir init --quiet 2>$null | Out-Null
        git -C $tmpDir config user.email 'test@test.com' 2>$null | Out-Null
        git -C $tmpDir config user.name 'Test' 2>$null | Out-Null
        Set-Content -Path (Join-Path $tmpDir 'README.md') -Value '# test' -Encoding utf8
        git -C $tmpDir add . 2>$null | Out-Null
        git -C $tmpDir commit -m 'init' --quiet 2>$null | Out-Null
        if ($BranchName -ne 'master') {
            git -C $tmpDir checkout -b $BranchName --quiet 2>$null | Out-Null
        }
        return $tmpDir
    }

    $script:FeatureRepo  = New-TempReleaseFlowRepo 'feature/test-feature'
    $script:ReleaseRepo  = New-TempReleaseFlowRepo 'release/v1.0.0'
    $script:NonRFRepo    = Join-Path $env:TEMP "kagents-norf-$(New-Guid)"
    New-Item -ItemType Directory -Path $script:NonRFRepo | Out-Null

    function script:Invoke-Guard([string]$Command, [string]$Cwd, [string]$ToolName = 'Bash') {
        @{
            tool_name  = $ToolName
            session_id = 'test'
            cwd        = $Cwd
            tool_input = @{ command = $Command }
        } | ConvertTo-Json -Compress -Depth 10 |
            pwsh -NoProfile -NonInteractive -File $script:GuardPath 2>$null
    }
}

AfterAll {
    Remove-Item $script:FeatureRepo  -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $script:ReleaseRepo  -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $script:NonRFRepo    -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'releaseflow-guardrail' {
    Context 'Direkter master-Merge blockiert' {
        It 'blockiert gh pr create --base master von Feature-Branch' {
            $output = Invoke-Guard 'gh pr create --base master --title "Test"' $script:FeatureRepo
            $result = $output | ConvertFrom-Json
            $result.decision | Should -Be 'block'
            $result.reason   | Should -Match 'ReleaseFlow-Guardrail'
        }
    }
    Context 'Release-Branch auf master erlaubt' {
        It 'laesst gh pr create --base master von release/v* durch' {
            Invoke-Guard 'gh pr create --base master --title "Stable"' $script:ReleaseRepo |
                Should -BeNullOrEmpty
        }
    }
    Context 'Feature-Branch auf dev/* erlaubt' {
        It 'laesst gh pr create --base dev/v1.0.0 durch' {
            Invoke-Guard 'gh pr create --base dev/v1.0.0 --title "Feature"' $script:FeatureRepo |
                Should -BeNullOrEmpty
        }
    }
    Context 'Kein ReleaseFlow-Repo — keine Pruefung' {
        It 'laesst gh pr create --base master in Nicht-RF-Repo durch' {
            Invoke-Guard 'gh pr create --base master --title "Test"' $script:NonRFRepo |
                Should -BeNullOrEmpty
        }
    }
    Context 'Nicht-Bash Tools werden ignoriert' {
        It 'laesst gh pr create bei Write-Tool durch' {
            @{
                tool_name  = 'Write'
                session_id = 'test'
                cwd        = $script:FeatureRepo
                tool_input = @{ command = 'gh pr create --base master' }
            } | ConvertTo-Json -Compress -Depth 10 |
                pwsh -NoProfile -NonInteractive -File $script:GuardPath 2>$null |
                Should -BeNullOrEmpty
        }
    }
    Context 'Normale Bash-Kommandos nicht betroffen' {
        It 'laesst git status durch' {
            Invoke-Guard 'git status' $script:FeatureRepo | Should -BeNullOrEmpty
        }
    }
    Context 'Break-Glass' {
        It 'laesst blockiertes Kommando durch wenn RELEASEFLOW_BYPASS=1' {
            $env:RELEASEFLOW_BYPASS = '1'
            try {
                Invoke-Guard 'gh pr create --base master --title "Test"' $script:FeatureRepo |
                    Should -BeNullOrEmpty
            } finally {
                Remove-Item Env:RELEASEFLOW_BYPASS -ErrorAction SilentlyContinue
            }
        }
    }
}

#Requires -Version 7.4
Set-StrictMode -Version Latest
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

Describe 'Install/Update-KAgentsVS.ps1 - Legacy-Cleanup bei aktivem Plugin' {

    BeforeAll {
        $script:InstallScript = Join-Path $PSScriptRoot '..' 'Install-KAgentsVS.ps1'
        $script:UpdateScript = Join-Path $PSScriptRoot '..' 'Update-KAgentsVS.ps1'
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $script:AgentsSource = Join-Path $script:RepoRoot 'plugins' 'kagents' 'agents'

        $script:KnownAgentNames = Get-ChildItem -Path $script:AgentsSource -Filter '*.agent.md' | Select-Object -ExpandProperty Name
        $script:KnownAgentName = $script:KnownAgentNames[0]

        $script:OriginalUserProfile = $env:USERPROFILE
    }

    AfterAll {
        $env:USERPROFILE = $script:OriginalUserProfile
    }

    BeforeEach {
        $script:TmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) "kagents-190-test-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:TmpRoot -Force | Out-Null

        $env:USERPROFILE = $script:TmpRoot

        $script:AgentsPath = Join-Path $script:TmpRoot '.github' 'agents'
        $script:SkillsPath = Join-Path $script:TmpRoot '.github' 'skills'
        New-Item -ItemType Directory -Path $script:AgentsPath -Force | Out-Null
        New-Item -ItemType Directory -Path $script:SkillsPath -Force | Out-Null

        $script:LegacyAgentPath = Join-Path $script:AgentsPath $script:KnownAgentName
        Set-Content -Path $script:LegacyAgentPath -Value 'legacy-agent-content' -NoNewline

        $script:ForeignAgentPath = Join-Path $script:AgentsPath 'foreign-custom.agent.md'
        Set-Content -Path $script:ForeignAgentPath -Value 'foreign-agent-content' -NoNewline

        $script:CopilotPluginAgentsPath = Join-Path $script:TmpRoot '.copilot' 'installed-plugins' 'kagents' 'kagents' 'agents'
        New-Item -ItemType Directory -Path $script:CopilotPluginAgentsPath -Force | Out-Null
    }

    AfterEach {
        Remove-Item -Path $script:TmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    Context 'Install-KAgentsVS.ps1' {

    It 'entfernt nur bekannte Legacy-K.Agents-Dateien und laesst fremde Agent-Dateien bestehen' {
        & $script:InstallScript -AgentsPath $script:AgentsPath -SkillsPath $script:SkillsPath -SkipInstructions *>&1 | Out-Null

        Test-Path $script:LegacyAgentPath | Should -BeFalse
        Test-Path $script:ForeignAgentPath | Should -BeTrue
    }

    It 'ist idempotent bei wiederholter Ausfuehrung' {
        & $script:InstallScript -AgentsPath $script:AgentsPath -SkillsPath $script:SkillsPath -SkipInstructions *>&1 | Out-Null
        & $script:InstallScript -AgentsPath $script:AgentsPath -SkillsPath $script:SkillsPath -SkipInstructions *>&1 | Out-Null

        Test-Path $script:LegacyAgentPath | Should -BeFalse
        Test-Path $script:ForeignAgentPath | Should -BeTrue

        $remaining = Get-ChildItem -Path $script:AgentsPath -Filter '*.agent.md' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
        @($remaining | Where-Object { $_ -in $script:KnownAgentNames }).Count | Should -Be 0
    }
    }

    Context 'Update-KAgentsVS.ps1' {

    It 'entfernt bekannte Legacy-Dateien und kopiert sie bei aktivem Plugin nicht erneut' {
        & $script:UpdateScript -AgentsPath $script:AgentsPath -SkillsPath $script:SkillsPath -SkipInstructions *>&1 | Out-Null

        Test-Path $script:LegacyAgentPath | Should -BeFalse
        Test-Path $script:ForeignAgentPath | Should -BeTrue

        $remaining = Get-ChildItem -Path $script:AgentsPath -Filter '*.agent.md' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
        @($remaining | Where-Object { $_ -in $script:KnownAgentNames }).Count | Should -Be 0
    }

    It 'kopiert Agents weiterhin, wenn kein Plugin installiert ist' {
        Remove-Item -Path (Join-Path $script:TmpRoot '.copilot') -Recurse -Force -ErrorAction SilentlyContinue

        & $script:UpdateScript -AgentsPath $script:AgentsPath -SkillsPath $script:SkillsPath -SkipInstructions *>&1 | Out-Null

        Test-Path $script:LegacyAgentPath | Should -BeTrue
    }
    }
}

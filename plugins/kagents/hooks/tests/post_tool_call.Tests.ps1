#Requires -Version 7.4
Set-StrictMode -Version Latest
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $script:PluginRoot = Join-Path $env:TEMP "kagents-test-$(New-Guid)"
    $env:CLAUDE_PLUGIN_ROOT = $script:PluginRoot
    $script:GuardPath = Join-Path $PSScriptRoot '..' 'post_tool_call.ps1'
    $script:LogFile   = Join-Path $script:PluginRoot 'logs' "$(Get-Date -Format 'yyyy-MM-dd').jsonl"

    function script:Invoke-Hook([hashtable]$HookData) {
        $HookData | ConvertTo-Json -Compress -Depth 10 |
            pwsh -NoProfile -NonInteractive -File $script:GuardPath 2>$null
        # Kurz warten, damit das Dateisystem die Log-Datei flusht
        Start-Sleep -Milliseconds 50
    }

    function script:Get-LastLogEntry {
        if (-not (Test-Path $script:LogFile)) { return $null }
        $lastLine = Get-Content $script:LogFile -Encoding utf8 -ErrorAction SilentlyContinue |
            Select-Object -Last 1
        if (-not $lastLine) { return $null }
        $lastLine | ConvertFrom-Json
    }
}

AfterAll {
    Remove-Item $script:PluginRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'post_tool_call' {
    BeforeEach {
        if (Test-Path $script:LogFile) { Remove-Item $script:LogFile -Force }
    }

    Context 'Fehler-Fall: is_error = true' {
        It 'loggt post_tool_use_failure-Event bei is_error:true' {
            Invoke-Hook @{
                tool_name     = 'Bash'
                session_id    = 'test-session'
                tool_input    = @{ command = 'ls' }
                tool_response = @{ is_error = $true; error = 'Permission denied' }
                agent_type    = 'claude'
            }
            $entry = Get-LastLogEntry
            $entry | Should -Not -BeNullOrEmpty
            $entry.event    | Should -Be 'post_tool_use_failure'
            $entry.tool_name | Should -Be 'Bash'
            $entry.error    | Should -Be 'Permission denied'
        }
    }
    Context 'Erfolgs-Fall: kein Fehler' {
        It 'loggt post_tool_use-Event bei normalem Response' {
            Invoke-Hook @{
                tool_name     = 'Read'
                session_id    = 'test-session'
                tool_input    = @{ file_path = '/tmp/test.txt' }
                tool_response = @{ content = 'file content' }
                agent_type    = 'claude'
            }
            $entry = Get-LastLogEntry
            $entry | Should -Not -BeNullOrEmpty
            $entry.event     | Should -Be 'post_tool_use'
            $entry.tool_name | Should -Be 'Read'
        }
    }
    Context 'Fehler-Fall: error-Key im Response' {
        It 'loggt Failure-Event bei error-Key in tool_response' {
            Invoke-Hook @{
                tool_name     = 'Write'
                session_id    = 'test-session'
                tool_input    = @{ file_path = '/tmp/x.txt' }
                tool_response = @{ error = 'File not found' }
                agent_type    = 'claude'
            }
            $entry = Get-LastLogEntry
            $entry | Should -Not -BeNullOrEmpty
            $entry.event | Should -Be 'post_tool_use_failure'
            $entry.error | Should -Be 'File not found'
        }
    }
    Context 'Kein tool_response — Erfolg' {
        It 'loggt post_tool_use ohne tool_response' {
            Invoke-Hook @{
                tool_name  = 'Bash'
                session_id = 'test-session'
                tool_input = @{ command = 'pwd' }
                agent_type = 'claude'
            }
            $entry = Get-LastLogEntry
            $entry | Should -Not -BeNullOrEmpty
            $entry.event      | Should -Be 'post_tool_use'
            $entry.has_response | Should -Be $false
        }
    }
}

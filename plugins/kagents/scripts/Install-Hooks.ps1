#Requires -Version 7.4

<#
.SYNOPSIS
    Registriert K.Agents Hooks in der Claude Code settings.json.

.DESCRIPTION
    Traegt die K.Agents Hook-Scripts (PreToolUse, PostToolUse, PostToolUseFailure)
    in die User-Level settings.json von Claude Code ein.
    Die Hook-Scripts loggen Agent-Events als JSONL nach ${CLAUDE_PLUGIN_ROOT}/logs/.

.PARAMETER Scope
    Installations-Scope: 'user' (Standard) oder 'project'.
    - user:    Aendert ~/.claude/settings.json (gilt fuer alle Repos)
    - project: Aendert .claude/settings.json im aktuellen Repo

.PARAMETER Uninstall
    Entfernt die K.Agents Hooks aus der settings.json.

.PARAMETER Force
    Ueberschreibt bestehende Hook-Eintraege ohne Rueckfrage.

.EXAMPLE
    .\Install-Hooks.ps1
    # Installiert Hooks auf User-Level

.EXAMPLE
    .\Install-Hooks.ps1 -Scope project
    # Installiert Hooks nur fuer das aktuelle Repo

.EXAMPLE
    .\Install-Hooks.ps1 -Uninstall
    # Entfernt K.Agents Hooks
#>
[CmdletBinding()]
param(
    [ValidateSet('user', 'project')]
    [string]$Scope = 'user',

    [switch]$Uninstall,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Pfade bestimmen
$hooksDir = Join-Path $PSScriptRoot '..' 'hooks'
$hooksDir = (Resolve-Path $hooksDir).Path

if ($Scope -eq 'user') {
    $settingsPath = Join-Path $env:USERPROFILE '.claude' 'settings.json'
} else {
    $settingsPath = Join-Path (Get-Location) '.claude' 'settings.json'
}

# Settings laden oder leeres Objekt erstellen
if (Test-Path $settingsPath) {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json -AsHashtable
} else {
    $settings = @{}
}

if ($Uninstall) {
    if ($settings.ContainsKey('hooks')) {
        $settings.Remove('hooks')
        $settingsDir = Split-Path $settingsPath -Parent
        if (-not (Test-Path $settingsDir)) {
            New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
        }
        $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding utf8
        Write-Output "K.Agents Hooks entfernt aus: $settingsPath"
    } else {
        Write-Output "Keine Hooks gefunden in: $settingsPath"
    }
    return
}

# Pruefen ob bereits Hooks vorhanden
if ($settings.ContainsKey('hooks') -and -not $Force) {
    $existingHooks = $settings['hooks']
    $hasKAgentsHook = $false
    foreach ($hookType in @('PreToolUse', 'PostToolUse', 'PostToolUseFailure')) {
        if ($existingHooks.ContainsKey($hookType)) {
            foreach ($matcher in $existingHooks[$hookType]) {
                if ($matcher.ContainsKey('hooks')) {
                    foreach ($hook in $matcher['hooks']) {
                        if ($hook['command'] -match 'kagents') {
                            $hasKAgentsHook = $true
                        }
                    }
                }
            }
        }
    }
    if ($hasKAgentsHook) {
        Write-Warning "K.Agents Hooks bereits vorhanden in: $settingsPath"
        Write-Warning "Nutze -Force zum Ueberschreiben oder -Uninstall zum Entfernen."
        return
    }
}

# Hook-Kommandos erstellen (cross-platform Pfade)
$preToolScript       = Join-Path $hooksDir 'pre_tool_call.ps1'
$guardrailScript     = Join-Path $hooksDir 'releaseflow-guardrail.ps1'
$postToolScript      = Join-Path $hooksDir 'post_tool_call.ps1'
$onErrorScript       = Join-Path $hooksDir 'on_error.ps1'

$hooksConfig = @{
    PreToolUse = @(
        @{
            matcher = 'Bash'
            hooks = @(
                @{
                    type    = 'command'
                    shell   = 'powershell'
                    command = "& `"$guardrailScript`""
                }
            )
        },
        @{
            matcher = ''
            hooks = @(
                @{
                    type = 'command'
                    shell = 'powershell'
                    command = "& `"$preToolScript`""
                }
            )
        }
    )
    PostToolUse = @(
        @{
            matcher = ''
            hooks = @(
                @{
                    type = 'command'
                    shell = 'powershell'
                    command = "& `"$postToolScript`""
                }
            )
        }
    )
    PostToolUseFailure = @(
        @{
            matcher = ''
            hooks = @(
                @{
                    type = 'command'
                    shell = 'powershell'
                    command = "& `"$onErrorScript`""
                }
            )
        }
    )
}

$settings['hooks'] = $hooksConfig

# Verzeichnis erstellen falls noetig
$settingsDir = Split-Path $settingsPath -Parent
if (-not (Test-Path $settingsDir)) {
    New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
}

$settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding utf8

$logsDir = [System.IO.Path]::GetFullPath((Join-Path $hooksDir '..' 'logs'))

Write-Output "K.Agents Hooks installiert ($Scope): $settingsPath"
Write-Output ''
Write-Output 'Registrierte Hooks:'
Write-Output "  PreToolUse (Bash)  -> $guardrailScript"
Write-Output "  PreToolUse         -> $preToolScript"
Write-Output "  PostToolUse        -> $postToolScript"
Write-Output "  PostToolUseFailure -> $onErrorScript"
Write-Output ''
Write-Output "Logs: $logsDir"
Write-Output "Log-Rotation: .\cleanup-logs.ps1 -RetentionDays 30"

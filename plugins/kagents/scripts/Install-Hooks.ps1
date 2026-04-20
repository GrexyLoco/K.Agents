#Requires -Version 7.4

<#
.SYNOPSIS
    Registriert K.Agents Hooks fuer Claude Code und/oder VS Code Copilot.

.DESCRIPTION
    Installiert die K.Agents Hook-Scripts (PreToolUse, PostToolUse) in
    die jeweils passende Konfiguration:

    - Target ClaudeCode: traegt die Hooks in die Claude Code settings.json
      ein (User- oder Project-Scope).
    - Target VSCode: zeigt die Registrierungsschritte fuer VS Code Copilot
      Chat / Copilot CLI an. Die eigentliche Hook-Definition liegt in
      plugins/kagents/hooks.json (Copilot-CLI-Format) und plugins/kagents/hooks/hooks.json
      (Claude-Format) und wird von VS Code auto-erkannt, sobald das Plugin
      per Plugin-Pfad registriert ist.
    - Target All: beide obigen Schritte.

    Die Hook-Scripts loggen Agent-Events als JSONL nach plugins/kagents/logs/.

.PARAMETER Target
    Installationsziel:
      - ClaudeCode (Default): Claude Code settings.json
      - VSCode: VS Code Copilot Chat / Copilot CLI
      - All: beide

.PARAMETER Scope
    Installations-Scope fuer ClaudeCode-Target: 'user' (Standard) oder 'project'.
    - user:    Aendert ~/.claude/settings.json (gilt fuer alle Repos)
    - project: Aendert .claude/settings.json im aktuellen Repo

.PARAMETER Uninstall
    Entfernt die K.Agents Hooks aus der Zielkonfiguration.

.PARAMETER Force
    Ueberschreibt bestehende Hook-Eintraege ohne Rueckfrage.

.EXAMPLE
    .\Install-Hooks.ps1
    # Installiert Hooks fuer Claude Code auf User-Level (Default)

.EXAMPLE
    .\Install-Hooks.ps1 -Target VSCode
    # Zeigt VS-Code-Registrierungsschritte fuer Copilot Chat / CLI

.EXAMPLE
    .\Install-Hooks.ps1 -Target All -Scope project
    # Registriert Claude Code (Projekt-Scope) + zeigt VS-Code-Hinweis

.EXAMPLE
    .\Install-Hooks.ps1 -Uninstall
    # Entfernt Claude Code Hooks aus der settings.json
#>
[CmdletBinding()]
param(
    [ValidateSet('ClaudeCode', 'VSCode', 'All')]
    [string]$Target = 'ClaudeCode',

    [ValidateSet('user', 'project')]
    [string]$Scope = 'user',

    [switch]$Uninstall,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Pfade bestimmen (cross-platform) ---
$hooksDir    = (Resolve-Path (Join-Path $PSScriptRoot '..' 'hooks')).Path
$pluginRoot  = Split-Path -Parent $hooksDir
$preToolScript    = Join-Path $hooksDir 'pre_tool_call.ps1'
$guardrailScript  = Join-Path $hooksDir 'releaseflow-guardrail.ps1'
$postToolScript   = Join-Path $hooksDir 'post_tool_call.ps1'

function Get-ClaudeSettingsPath {
    param([string]$Scope)
    if ($Scope -eq 'user') {
        $home = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
        return Join-Path $home '.claude' 'settings.json'
    }
    return Join-Path (Get-Location) '.claude' 'settings.json'
}

function New-ClaudeHookEntry {
    param([Parameter(Mandatory)][string]$ScriptPath)
    $quoted = "`"$ScriptPath`""
    # OS-Overrides fuer Cross-Platform-Kompatibilitaet (VS Code auto-erkennt Claude-Format).
    # Bei absoluten Pfaden reicht Token-loses command; Overrides sind dennoch gesetzt fuer
    # konsistentes Quoting pro OS.
    @{
        type    = 'command'
        command = "pwsh -NoProfile -File $quoted"
        windows = "pwsh -NoProfile -File $quoted"
        linux   = "pwsh -NoProfile -File '$ScriptPath'"
        osx     = "pwsh -NoProfile -File '$ScriptPath'"
    }
}

function Install-ClaudeHooks {
    param([string]$Scope, [switch]$Uninstall, [switch]$Force)

    $settingsPath = Get-ClaudeSettingsPath -Scope $Scope
    $settings = if (Test-Path $settingsPath) {
        Get-Content $settingsPath -Raw | ConvertFrom-Json -AsHashtable
    } else { @{} }

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

    if ($settings.ContainsKey('hooks') -and -not $Force) {
        $existingHooks = $settings['hooks']
        $hasKAgentsHook = $false
        foreach ($hookType in @('PreToolUse', 'PostToolUse')) {
            if ($existingHooks.ContainsKey($hookType)) {
                foreach ($matcher in $existingHooks[$hookType]) {
                    if ($matcher.ContainsKey('hooks')) {
                        foreach ($hook in $matcher['hooks']) {
                            if ($hook['command'] -match 'kagents') { $hasKAgentsHook = $true }
                        }
                    }
                }
            }
        }
        if ($hasKAgentsHook) {
            Write-Warning "K.Agents Hooks bereits vorhanden in: $settingsPath"
            Write-Warning 'Nutze -Force zum Ueberschreiben oder -Uninstall zum Entfernen.'
            return
        }
    }

    $hooksConfig = @{
        PreToolUse = @(
            @{ matcher = 'Bash'; hooks = @( New-ClaudeHookEntry -ScriptPath $guardrailScript ) }
            @{ matcher = '';     hooks = @( New-ClaudeHookEntry -ScriptPath $preToolScript   ) }
        )
        PostToolUse = @(
            @{ matcher = ''; hooks = @( New-ClaudeHookEntry -ScriptPath $postToolScript ) }
        )
    }

    $settings['hooks'] = $hooksConfig

    $settingsDir = Split-Path $settingsPath -Parent
    if (-not (Test-Path $settingsDir)) {
        New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
    }
    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding utf8

    Write-Output "K.Agents Hooks installiert ($Scope): $settingsPath"
    Write-Output ''
    Write-Output 'Registrierte Hooks:'
    Write-Output "  PreToolUse (Bash)  -> $guardrailScript"
    Write-Output "  PreToolUse         -> $preToolScript"
    Write-Output "  PostToolUse        -> $postToolScript"
    Write-Output '  (PostToolUseFailure ist konsolidiert in post_tool_call.ps1 — VS-Code-kompatibel)'
}

function Show-VSCodeHint {
    Write-Output ''
    Write-Output '--- VS Code Copilot Integration ---'
    Write-Output ''
    Write-Output 'Die Hook-Definition ist bereits bereit:'
    Write-Output "  - Claude-Format (Plugin-Discovery): $pluginRoot/hooks/hooks.json"
    Write-Output "  - Copilot-CLI-Format (Plugin-Root): $pluginRoot/hooks.json"
    Write-Output ''
    Write-Output 'Beide Dateien nutzen ${CLAUDE_PLUGIN_ROOT} Token-Syntax und OS-spezifische'
    Write-Output 'Command-Overrides (windows/linux/osx). VS Code Copilot Chat und Copilot CLI'
    Write-Output 'erkennen die Hooks automatisch, sobald das Plugin in der entsprechenden'
    Write-Output 'Agent-Plugin-Konfiguration registriert ist.'
    Write-Output ''
    Write-Output 'Dokumentation: https://code.visualstudio.com/docs/copilot/customization/agent-plugins'
}

# --- Ausfuehrung ---
switch ($Target) {
    'ClaudeCode' { Install-ClaudeHooks -Scope $Scope -Uninstall:$Uninstall -Force:$Force }
    'VSCode'     {
        if ($Uninstall) {
            Write-Output 'VS-Code-Target: Uninstall ist ein manueller Schritt (Plugin aus Agent-Config entfernen).'
        } else {
            Show-VSCodeHint
        }
    }
    'All'        {
        Install-ClaudeHooks -Scope $Scope -Uninstall:$Uninstall -Force:$Force
        if (-not $Uninstall) { Show-VSCodeHint }
    }
}

$logsDir = Join-Path $pluginRoot 'logs'
Write-Output ''
Write-Output "Logs: $logsDir"
Write-Output "Log-Rotation: $PSScriptRoot/cleanup-logs.ps1 -RetentionDays 30"

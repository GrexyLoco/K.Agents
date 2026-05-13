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
      plugins/kagents/hooks/hooks.json (Claude-Format) und wird von VS Code
      auto-erkannt, sobald das Plugin per Plugin-Pfad registriert ist.
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

.EXAMPLE
    .\Install-Hooks.ps1 -GitHooks
    # Installiert den git commit-msg Hook im aktuellen Repository

.EXAMPLE
    .\Install-Hooks.ps1 -Target All -GitHooks
    # Installiert Claude Code Hooks (User-Scope) + git commit-msg Hook
#>
[CmdletBinding()]
param(
    [ValidateSet('ClaudeCode', 'VSCode', 'All')]
    [string]$Target = 'ClaudeCode',

    [ValidateSet('user', 'project')]
    [string]$Scope = 'user',

    [switch]$Uninstall,
    [switch]$Force,

    [switch]$GitHooks
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
    [CmdletBinding()]
    param([string]$Scope)
    if ($Scope -eq 'user') {
        $userHome = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
        return Join-Path $userHome '.claude' 'settings.json'
    }
    return Join-Path (Get-Location) '.claude' 'settings.json'
}

function New-ClaudeHookEntry {
    [CmdletBinding()]
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

function Test-IsLegacyHookEntry {
    <#
    .SYNOPSIS
        Prueft ob ein Hook-Eintrag das veraltete Muster verwendet.
    .DESCRIPTION
        Erkennt Legacy-Eintraege die mit powershell.exe (5.1) ausgefuehrt werden:
        - Eintrag hat eine 'shell'-Property (neues Format hat keine)
        - command nutzt '& "' (PS-Invoke-Syntax statt direktem pwsh-Aufruf)
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][hashtable]$HookEntry)
    if ($HookEntry.ContainsKey('shell')) { return $true }
    if ($HookEntry.ContainsKey('command') -and $HookEntry['command'] -match '^\s*&\s+"') { return $true }
    return $false
}

function Remove-LegacyHookEntries {
    <#
    .SYNOPSIS
        Entfernt veraltete K.Agents Hook-Eintraege aus dem hooks-Block.
    .DESCRIPTION
        Durchsucht alle Hook-Typen (PreToolUse, PostToolUse) nach Eintraegen
        mit dem Legacy-Muster und entfernt diese. Fremde Hooks (kein kagents-Bezug)
        bleiben unveraendert.
        Gibt $true zurueck wenn mindestens ein Legacy-Eintrag entfernt wurde.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][hashtable]$Settings)

    if (-not $Settings.ContainsKey('hooks')) { return $false }

    $removed = $false
    foreach ($hookType in @('PreToolUse', 'PostToolUse')) {
        if (-not $Settings['hooks'].ContainsKey($hookType)) { continue }
        $matchers = $Settings['hooks'][$hookType]
        $updatedMatchers = [System.Collections.Generic.List[object]]::new()
        foreach ($matcher in $matchers) {
            if (-not $matcher.ContainsKey('hooks')) {
                $updatedMatchers.Add($matcher)
                continue
            }
            $filteredHooks = [System.Collections.Generic.List[object]]::new()
            foreach ($hook in $matcher['hooks']) {
                $isKAgentsHook = $hook.ContainsKey('command') -and
                    $hook['command'] -match 'kagents|pre_tool_call|post_tool_call|releaseflow-guardrail'
                if ($isKAgentsHook -and (Test-IsLegacyHookEntry -HookEntry $hook)) {
                    $removed = $true
                } else {
                    $filteredHooks.Add($hook)
                }
            }
            # Matcher beibehalten wenn noch Hooks verbleiben; leere Matcher weglassen
            if ($filteredHooks.Count -gt 0) {
                $matcher['hooks'] = $filteredHooks.ToArray()
                $updatedMatchers.Add($matcher)
            }
        }
        $Settings['hooks'][$hookType] = $updatedMatchers.ToArray()
    }
    return $removed
}

function Install-ClaudeHooks {
    [CmdletBinding()]
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

    # Legacy-Migration: veraltete Eintraege (shell: powershell / & "...") automatisch ersetzen
    $legacyMigrated = Remove-LegacyHookEntries -Settings $settings
    if ($legacyMigrated) {
        Write-Warning "Veraltete K.Agents Hook-Eintraege (powershell.exe/& `"-Muster) wurden migriert."
        Write-Warning "Schreibe neue Eintraege mit pwsh -NoProfile -File..."
    }

    if (-not $legacyMigrated -and $settings.ContainsKey('hooks') -and -not $Force) {
        $existingHooks = $settings['hooks']
        $hasKAgentsHook = $false
        foreach ($hookType in @('PreToolUse', 'PostToolUse')) {
            if ($existingHooks.ContainsKey($hookType)) {
                foreach ($matcher in $existingHooks[$hookType]) {
                    if ($matcher.ContainsKey('hooks')) {
                        foreach ($hook in $matcher['hooks']) {
                            if ($hook.ContainsKey('command') -and $hook['command'] -match 'kagents') { $hasKAgentsHook = $true }
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

    # Hooks mergen: bestehende Nicht-K.Agents-Eintraege beibehalten, kagents-Eintraege anfuegen
    if (-not $settings.ContainsKey('hooks')) { $settings['hooks'] = @{} }
    foreach ($hookType in $hooksConfig.Keys) {
        $merged = [System.Collections.Generic.List[object]]::new()
        if ($settings['hooks'].ContainsKey($hookType)) {
            foreach ($entry in @($settings['hooks'][$hookType])) {
                $merged.Add($entry)
            }
        }
        foreach ($entry in @($hooksConfig[$hookType])) {
            $merged.Add($entry)
        }
        $settings['hooks'][$hookType] = $merged.ToArray()
    }

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
    [CmdletBinding()]
    param()
    Write-Output ''
    Write-Output '--- VS Code Copilot Integration ---'
    Write-Output ''
    Write-Output 'Die Hook-Definition ist bereits bereit:'
    $claudeHooksJson  = Join-Path $pluginRoot 'hooks' 'hooks.json'
    Write-Output "  - Claude-Format (Plugin-Discovery): $claudeHooksJson"
    Write-Output ''
    Write-Output 'Die Datei nutzt ${CLAUDE_PLUGIN_ROOT} Token-Syntax und OS-spezifische'
    Write-Output 'Command-Overrides (windows/linux/osx). VS Code Copilot Chat und Copilot CLI'
    Write-Output 'erkennen die Hooks automatisch, sobald das Plugin in der entsprechenden'
    Write-Output 'Agent-Plugin-Konfiguration registriert ist.'
    Write-Output ''
    Write-Output 'Dokumentation: https://code.visualstudio.com/docs/copilot/customization/agent-plugins'
}

function Install-GitHooks {
    <#
    .SYNOPSIS
        Installiert den git commit-msg Hook als nativen git Hook im aktuellen Repository.
    .DESCRIPTION
        Schreibt einen Shell-Shim nach .git/hooks/commit-msg der commit-msg.ps1 aufruft.
        Prueft vorher ob core.hooksPath gesetzt ist — falls ja, Warnung und Abbruch.
        Auf Linux/macOS wird der Shim ausfuehrbar gemacht (chmod +x).
    #>
    [CmdletBinding()]
    param()

    # Pruefe ob wir in einem git-Repository sind
    $gitDir = git rev-parse --git-dir 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning 'Kein git-Repository gefunden. git commit-msg Hook konnte nicht installiert werden.'
        Write-Warning 'Fuehre Install-Hooks.ps1 aus dem Wurzelverzeichnis eines git-Repos aus.'
        return
    }

    # core.hooksPath pruefen — falls gesetzt, kann .git/hooks/ ignoriert werden
    $customHooksPath = git config --get core.hooksPath 2>&1
    if ($LASTEXITCODE -eq 0 -and $customHooksPath) {
        Write-Warning "git config core.hooksPath ist gesetzt: '$customHooksPath'"
        Write-Warning "Der Shim kann nicht automatisch nach .git/hooks/commit-msg geschrieben werden."
        Write-Warning "Kopiere commit-msg.ps1 manuell in: $customHooksPath"
        Write-Warning "Und erstelle dort einen Shim (commit-msg ohne Erweiterung) der commit-msg.ps1 aufruft."
        return
    }

    # commit-msg.ps1 absoluten Pfad ermitteln
    $commitMsgScript = (Resolve-Path (Join-Path $PSScriptRoot '..' 'hooks' 'commit-msg.ps1')).Path

    # .git/hooks/ Verzeichnis
    $gitDirPath = (Resolve-Path $gitDir).Path
    $hooksPath = Join-Path $gitDirPath 'hooks'
    if (-not (Test-Path $hooksPath)) {
        New-Item -ItemType Directory -Path $hooksPath -Force | Out-Null
    }

    $shimPath = Join-Path $hooksPath 'commit-msg'

    # Shim-Inhalt mit LF-Zeilenenden (git for Windows erfordert LF)
    $shimContent = "#!/bin/sh`nexec pwsh -NoProfile -File `"$commitMsgScript`" `"`$@`"`n"

    # BOM-freies UTF-8 mit LF (BOM bricht Shebang auf Linux/macOS)
    [System.IO.File]::WriteAllText($shimPath, $shimContent, [System.Text.UTF8Encoding]::new($false))

    # Auf Linux/macOS: ausfuehrbar machen
    if (-not $IsWindows) {
        chmod +x $shimPath
    }

    Write-Output "git commit-msg Hook installiert: $shimPath"
    Write-Output "  -> $commitMsgScript"
    Write-Output ''
    Write-Output 'Der Hook wird bei jedem git commit ausgefuehrt (unabhaengig vom verwendeten Tool).'
    Write-Output "Break-Glass: `$env:KAGENTS_COMMIT_BYPASS = '1'"
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

if ($GitHooks) {
    Install-GitHooks
}

$logsDir = Join-Path $pluginRoot 'logs'
Write-Output ''
Write-Output "Logs: $logsDir"
$cleanupScript = Join-Path $PSScriptRoot 'cleanup-logs.ps1'
Write-Output "Log-Rotation: $cleanupScript -RetentionDays 30"

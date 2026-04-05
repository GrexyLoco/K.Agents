#Requires -Version 7.4

<#
.SYNOPSIS
    Entfernt ausschliesslich K.Agents Hooks aus der Claude Code settings.json.

.DESCRIPTION
    Durchsucht die Claude Code settings.json nach Hook-Eintraegen, die
    'kagents' im command-String enthalten, und entfernt
    nur diese. Andere Hooks bleiben unangetastet.
    Leere Hook-Arrays und der hooks-Key selbst werden aufgeraeumt.

.PARAMETER Scope
    Deinstallations-Scope: 'user' (Standard) oder 'project'.
    - user:    Aendert ~/.claude/settings.json
    - project: Aendert .claude/settings.json im aktuellen Repo

.PARAMETER WhatIf
    Zeigt was entfernt wuerde, ohne Aenderungen vorzunehmen.

.EXAMPLE
    .\Uninstall-Hooks.ps1
    # Entfernt K.Agents Hooks aus User-Settings

.EXAMPLE
    .\Uninstall-Hooks.ps1 -Scope project
    # Entfernt K.Agents Hooks aus Projekt-Settings

.EXAMPLE
    .\Uninstall-Hooks.ps1 -WhatIf
    # Zeigt was entfernt wuerde
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('user', 'project')]
    [string]$Scope = 'user'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Pfad bestimmen
if ($Scope -eq 'user') {
    $settingsPath = Join-Path $env:USERPROFILE '.claude' 'settings.json'
} else {
    $settingsPath = Join-Path (Get-Location) '.claude' 'settings.json'
}

if (-not (Test-Path $settingsPath)) {
    Write-Output "Settings-Datei nicht gefunden: $settingsPath"
    return
}

$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json -AsHashtable

if (-not $settings.ContainsKey('hooks')) {
    Write-Output "Keine Hooks in: $settingsPath"
    return
}

$hooks = $settings['hooks']
$removedCount = 0

# Jeden Hook-Typ durchgehen
foreach ($hookType in @($hooks.Keys)) {
    $matchers = $hooks[$hookType]
    if ($matchers -isnot [System.Collections.IList]) {
        continue
    }

    # Matcher filtern: nur behalten, die KEINE K.Agents-Hooks sind
    $cleanedMatchers = [System.Collections.ArrayList]::new()
    foreach ($matcher in $matchers) {
        if ($matcher -isnot [hashtable] -and $matcher -isnot [System.Collections.Specialized.OrderedDictionary]) {
            [void]$cleanedMatchers.Add($matcher)
            continue
        }

        if (-not $matcher.ContainsKey('hooks')) {
            [void]$cleanedMatchers.Add($matcher)
            continue
        }

        $cleanedHooks = [System.Collections.ArrayList]::new()
        foreach ($hook in $matcher['hooks']) {
            $command = if ($hook.ContainsKey('command')) { $hook['command'] } else { '' }
            if ($command -match 'kagents|k-agents|k_agents') {
                $removedCount++
                if ($WhatIfPreference) {
                    Write-Output "[WhatIf] Wuerde entfernen: $hookType -> $command"
                }
            } else {
                [void]$cleanedHooks.Add($hook)
            }
        }

        if ($cleanedHooks.Count -gt 0) {
            $matcher['hooks'] = @($cleanedHooks)
            [void]$cleanedMatchers.Add($matcher)
        }
    }

    if ($cleanedMatchers.Count -gt 0) {
        $hooks[$hookType] = @($cleanedMatchers)
    } else {
        $hooks.Remove($hookType)
    }
}

# hooks-Key entfernen wenn komplett leer
if ($hooks.Count -eq 0) {
    $settings.Remove('hooks')
}

if ($removedCount -eq 0) {
    Write-Output "Keine K.Agents Hooks gefunden in: $settingsPath"
    return
}

if ($WhatIfPreference) {
    Write-Output "[WhatIf] $removedCount Hook(s) wuerden entfernt."
    return
}

if ($PSCmdlet.ShouldProcess($settingsPath, "$removedCount K.Agents Hook(s) entfernen")) {
    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding utf8
    Write-Output "$removedCount K.Agents Hook(s) entfernt aus: $settingsPath"
}

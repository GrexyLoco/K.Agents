#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    K.Agents PreToolUse-Guard: Blockiert potenziell destruktive Bash-Kommandos.

.DESCRIPTION
    Prueft bei Bash-Tool-Aufrufen, ob das Kommando einem bekannten destruktiven Muster entspricht,
    und blockiert es vor der Ausfuehrung. Schreibt jeden Block und jeden Bypass-Vorgang in das
    tagesaktuelle Log.

    Blockierte Patterns:
        Pattern-Name         Muster
        -------------------- ------------------------------------------------
        rm -rf /             rm\s+-rf\s+/
        rm -rf ~             rm\s+-rf\s+~
        rm -rf $HOME         rm\s+-rf\s+\$HOME
        rm -rf *             rm\s+-rf\s+\*
        git push --force     git\s+push\s+--force(?!-with-lease)
        git reset --hard     git\s+reset\s+--hard
        DROP TABLE           (?i)\bDROP\s+TABLE\b
        DROP DATABASE        (?i)\bDROP\s+DATABASE\b
        TRUNCATE TABLE       (?i)\bTRUNCATE\s+TABLE\b
        chmod 777            \bchmod\s+777\b
        mkfs                 \bmkfs\b
        dd if=               \bdd\s+if=
        > /dev/sd            >\s*/dev/[sh]d[a-z]

    Allowlist (werden NICHT blockiert, auch wenn ein Block-Muster greifen wuerde):
        - rm -rf node_modules
        - rm -rf bin/
        - rm -rf obj/
        - git push --force-with-lease

    Break-Glass:
        Setze KAGENTS_DESTRUCTIVE_BYPASS=1 in der Shell, um alle Pruefungen zu umgehen.
        Jeder Bypass-Vorgang wird im Log protokolliert.

.NOTES
    Hook-Typ:    PreToolUse
    Matcher:     Bash
    Exit-Code 0 + JSON {"decision":"block","reason":"..."}: Kommando blockiert.
    Exit-Code 0 (kein Output):                              Kommando zugelassen.
#>

# --- stdin lesen (Claude Code sendet JSON via stdin) ---
. (Join-Path $PSScriptRoot 'HookHelpers.ps1')
$hookData = Read-HookStdin

# Nur Bash-Tool-Aufrufe pruefen
if ($hookData['tool_name'] -ne 'Bash') { exit 0 }

# Command extrahieren
$toolInput = $hookData['tool_input']
$command = if ($toolInput -is [hashtable] -and $toolInput.ContainsKey('command')) {
    $toolInput['command']
} elseif ($toolInput -is [string]) { $toolInput } else { '' }
if (-not $command) { exit 0 }

# --- Break-Glass: KAGENTS_DESTRUCTIVE_BYPASS=1 ---
if ($env:KAGENTS_DESTRUCTIVE_BYPASS -eq '1') {
    $logFile = Initialize-LogFile
    Write-HookLogEntry -LogFile $logFile -Entry ([ordered]@{
        timestamp  = (Get-Date -Format 'o')
        session_id = $hookData['session_id']
        event      = 'destructive_guard_bypass'
        tool_name  = $hookData['tool_name']
        command    = $command.Substring(0, [Math]::Min(200, $command.Length))
    })
    exit 0
}

# --- Allowlist (zuerst pruefen — bei Match kein Block) ---
$allowlist = @(
    'rm\s+-rf\s+node_modules',
    'rm\s+-rf\s+bin[/\\]',
    'rm\s+-rf\s+obj[/\\]',
    'git\s+push\s+--force-with-lease'
)
foreach ($allow in $allowlist) {
    if ($command -match $allow) { exit 0 }
}

# --- Block-Patterns ---
$blockPatterns = [ordered]@{
    'rm -rf /'         = 'rm\s+-rf\s+/'
    'rm -rf ~'         = 'rm\s+-rf\s+~'
    'rm -rf $HOME'     = 'rm\s+-rf\s+\$HOME'
    'rm -rf *'         = 'rm\s+-rf\s+\*'
    'git push --force' = 'git\s+push\s+--force(?!-with-lease)'
    'git reset --hard' = 'git\s+reset\s+--hard'
    'DROP TABLE'       = '(?i)\bDROP\s+TABLE\b'
    'DROP DATABASE'    = '(?i)\bDROP\s+DATABASE\b'
    'TRUNCATE TABLE'   = '(?i)\bTRUNCATE\s+TABLE\b'
    'chmod 777'        = '\bchmod\s+777\b'
    'mkfs'             = '\bmkfs\b'
    'dd if='           = '\bdd\s+if='
    '> /dev/sd'        = '>\s*/dev/[sh]d[a-z]'
}

foreach ($entry in $blockPatterns.GetEnumerator()) {
    if ($command -match $entry.Value) {
        $patternName = $entry.Key

        # Block-Vorgang ins Log schreiben
        $logFile = Initialize-LogFile
        Write-HookLogEntry -LogFile $logFile -Entry ([ordered]@{
            timestamp    = (Get-Date -Format 'o')
            session_id   = $hookData['session_id']
            event        = 'destructive_guard_block'
            tool_name    = $hookData['tool_name']
            pattern_name = $patternName
            command      = $command.Substring(0, [Math]::Min(200, $command.Length))
        })

        Write-Output (ConvertTo-Json ([ordered]@{
            decision = 'block'
            reason   = "Destructive Command Guard: Potenziell destruktives Kommando erkannt ('$patternName'). Pruefe den Befehl sorgfaeltig. Break-Glass: KAGENTS_DESTRUCTIVE_BYPASS=1"
        }) -Compress)
        exit 0
    }
}

exit 0

#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    K.Agents PreToolUse-Guard: Validiert git commit -m Nachrichten auf Conventional Commit Format.
.DESCRIPTION
    Prueft Bash-Kommandos auf 'git commit -m' und validiert die Nachricht gegen das Template:
    <type>(<scope>): <description>

    - <what>, <why>

    Ref #<issue>

    Checks:
    - Type vorhanden: feat|fix|docs|style|refactor|perf|test|chore|ci
    - Scope ohne Leerzeichen
    - Description nicht leer, Kleinbuchstabe
    - Body mit Bulletpoints
    - Kein Closes/Fixes # (nur Ref # erlaubt)

    Nicht geprueft: --file, --allow-empty-message Commits
    Break-Glass: KAGENTS_COMMIT_BYPASS=1
#>

. (Join-Path $PSScriptRoot 'HookHelpers.ps1')
$hookData = Read-HookStdin
if ($hookData['tool_name'] -ne 'Bash') { exit 0 }

$toolInput = $hookData['tool_input']
$command = if ($toolInput -is [hashtable] -and $toolInput.ContainsKey('command')) {
    $toolInput['command']
} elseif ($toolInput -is [string]) { $toolInput } else { '' }
if (-not $command) { exit 0 }

# Nur git commit Befehle
if ($command -notmatch 'git\s+commit\b') { exit 0 }

# Automatisierte Commits nicht pruefen
if ($command -match '--file\b|--allow-empty-message\b') { exit 0 }

# --- Break-Glass: KAGENTS_COMMIT_BYPASS=1 ---
if ($env:KAGENTS_COMMIT_BYPASS -eq '1') {
    $logFile = Initialize-LogFile
    Write-HookLogEntry -LogFile $logFile -Entry ([ordered]@{
        timestamp  = (Get-Date -Format 'o')
        session_id = $hookData['session_id']
        event      = 'commit_guard_bypass'
    })
    exit 0
}

# --- Commit-Nachricht aus -m extrahieren ---
$msg = $null
if ($command -match '(?s)-m\s+"(.*?)"(?:\s|$)') {
    $msg = $Matches[1]
} elseif ($command -match "(?s)-m\s+'(.*?)'(?:\s|`$)") {
    $msg = $Matches[1]
} elseif ($command -match '(?s)-m\s+\$\(cat\s+<<''EOF''(.*?)EOF\s*\)') {
    $msg = $Matches[1].Trim()
}
# Wenn keine Nachricht extrahierbar → nicht pruefen
if (-not $msg) { exit 0 }

# --- Template fuer Block-Ausgabe ---
$template = @"
feat(scope): kurze beschreibung

- was geaendert, warum
- weiteres, grund

Ref #123
"@

function Write-CommitBlock {
    [CmdletBinding()]
    param([string]$BlockReason)
    Write-Output (ConvertTo-Json ([ordered]@{
        decision = 'block'
        reason   = "Conventional Commit Guard: $BlockReason`n`nErwartetes Template:`n$template`nBreak-Glass: KAGENTS_COMMIT_BYPASS=1"
    }) -Compress)
    exit 0
}

# --- Checks ---
$lines = $msg -split "`n"
$header = $lines[0].Trim()

# 1. Type pruefen
if ($header -notmatch '^(feat|fix|docs|style|refactor|perf|test|chore|ci)[\(:]') {
    Write-CommitBlock -BlockReason 'Fehlender oder ungueltiger Type. Erlaubt: feat|fix|docs|style|refactor|perf|test|chore|ci'
}

# 2. Kein Closes/Fixes (Auto-Close)
if ($msg -match '(?i)\b(Closes?\s*#|Fixes?\s*#)') {
    Write-CommitBlock -BlockReason "Nur 'Ref #' ist erlaubt — kein 'Closes #' oder 'Fixes #' (kein Auto-Close via Commit)"
}

# 3. Description nicht leer + Kleinbuchstabe
if ($header -match '^[a-z]+(?:\([^)]+\))?\:\s*(.+)$') {
    $description = $Matches[1]
    if ($description.Length -eq 0 -or $description -cmatch '^[A-Z]') {
        Write-CommitBlock -BlockReason 'Description darf nicht leer sein und muss mit Kleinbuchstabe beginnen'
    }
}

# 4. Body mit Bulletpoints
$bodyLines = $lines | Select-Object -Skip 1
$hasBullets = $bodyLines | Where-Object { $_ -match '^\s*[-*]\s+\S' }
if (-not $hasBullets) {
    Write-CommitBlock -BlockReason 'Body fehlt oder enthaelt keine Bulletpoints (- oder * gefolgt von Text)'
}

exit 0

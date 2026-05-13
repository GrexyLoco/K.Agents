#Requires -Version 7.4

<#
.SYNOPSIS
    K.Agents git commit-msg Hook: Validiert Commit-Nachrichten auf Conventional Commit Format.
.DESCRIPTION
    Nativer git commit-msg Hook — laeuft bei JEDEM Commit, unabhaengig vom verwendeten Tool.

    Prueft die Commit-Nachricht gegen das Template:
    <type>(<scope>): <description>

    - <was geaendert>
    - <weiteres>

    Ref #<issue>

    Checks:
    - Type vorhanden: feat|fix|docs|style|refactor|perf|test|chore|ci
    - Description nicht leer, beginnt mit Kleinbuchstabe
    - Body mit Bulletpoints (- oder *)
    - Kein Closes/Fixes # (nur Ref # erlaubt)

    Automatisch uebersprungen:
    - Merge-Commits (erste Zeile beginnt mit "Merge ")
    - Fixup/Squash-Commits (fixup! oder squash! Prefix)
    - Commits mit [skip ci] im Subject

    Break-Glass: KAGENTS_COMMIT_BYPASS=1
.PARAMETER CommitMsgFile
    Pfad zur Datei mit der Commit-Nachricht (git-hook-Protokoll: $1)
#>

param(
    [Parameter(Mandatory)]
    [string]$CommitMsgFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Commit-Nachricht lesen ---
$msg = Get-Content $CommitMsgFile -Raw -ErrorAction Stop
if (-not $msg) { exit 0 }

$lines = $msg -split "`n"
$header = $lines[0].TrimEnd()

# --- Sonderfaelle ueberspringen ---

# Merge-Commits
if ($header -match '^Merge ') { exit 0 }

# Fixup/Squash-Commits
if ($header -match '^(fixup|squash)!') { exit 0 }

# [skip ci] im Subject
if ($header -match '\[skip ci\]') { exit 0 }

# Break-Glass: KAGENTS_COMMIT_BYPASS=1
if ($env:KAGENTS_COMMIT_BYPASS -eq '1') { exit 0 }

# --- Template fuer Fehlermeldungen ---
$template = @'
feat(scope): kurze beschreibung

- was geaendert, warum
- weiteres, grund

Ref #123
'@

function Write-ValidationError {
    [CmdletBinding()]
    param([string]$Reason)
    $divider = '-' * 60
    [Console]::Error.WriteLine('')
    [Console]::Error.WriteLine($divider)
    [Console]::Error.WriteLine("COMMIT ABGELEHNT: $Reason")
    [Console]::Error.WriteLine('')
    [Console]::Error.WriteLine('Erwartetes Format:')
    [Console]::Error.WriteLine($template)
    [Console]::Error.WriteLine("Break-Glass: `$env:KAGENTS_COMMIT_BYPASS = '1'")
    [Console]::Error.WriteLine($divider)
    [Console]::Error.WriteLine('')
    exit 1
}

# --- Validierung ---

# 1. Type pruefen
if ($header -notmatch '^(feat|fix|docs|style|refactor|perf|test|chore|ci)[\(:]') {
    Write-ValidationError -Reason 'Fehlender oder ungueltiger Type. Erlaubt: feat|fix|docs|style|refactor|perf|test|chore|ci'
}

# 2. Kein Closes/Fixes (Auto-Close) — case-insensitive
if ($msg -match '(?i)\b(Closes?\s*#|Fixes?\s*#)') {
    Write-ValidationError -Reason "Nur 'Ref #' ist erlaubt — kein 'Closes #' oder 'Fixes #' (kein Auto-Close via Commit)"
}

# 3. Description nicht leer + muss mit Kleinbuchstabe beginnen
if ($header -match '^[a-z]+(?:\([^)]+\))?\:\s*(.+)$') {
    $description = $Matches[1]
    if ($description.Length -eq 0 -or $description -cmatch '^[A-Z]') {
        Write-ValidationError -Reason 'Description darf nicht leer sein und muss mit Kleinbuchstabe beginnen'
    }
}

# 4. Body mit Bulletpoints pruefen
$bodyLines = $lines | Select-Object -Skip 1
$hasBullets = $bodyLines | Where-Object { $_ -match '^\s*[-*]\s+\S' }
if (-not $hasBullets) {
    Write-ValidationError -Reason 'Body fehlt oder enthaelt keine Bulletpoints (- oder * gefolgt von Text)'
}

exit 0

#Requires -Version 7.4

<#
.SYNOPSIS
    Behebt Merge-Konflikte zwischen einem Release-Branch und einem Source-Branch
    in einem zweistufigen Prozess.

.DESCRIPTION
    Phase 1 (-Prepare): Erstellt einen Fix-Branch, fuehrt einen probeweisen Merge
    durch und listet Konflikt-Dateien auf. Der Nutzer behebt die Konflikte manuell.

    Phase 2 (-Complete): Committet die geloesten Konflikte, pusht den Branch und
    erstellt einen PR gegen den Release-Branch mit Auto-Merge.

.PARAMETER ReleaseBranch
    Name des Ziel-Release-Branches (z.B. 'release/v1.15.0'). Pflichtparameter.

.PARAMETER SourceBranch
    Name des Quell-Branches (Standard: 'master').

.PARAMETER Prepare
    Phase 1: Fix-Branch anlegen und Merge vorbereiten.

.PARAMETER Complete
    Phase 2: Konflikte committen, pushen und PR erstellen.

.EXAMPLE
    .\Invoke-ReleaseConflictFix.ps1 -ReleaseBranch 'release/v1.15.0' -Prepare
    # Phase 1: Fix-Branch erstellen, Konflikte anzeigen

.EXAMPLE
    .\Invoke-ReleaseConflictFix.ps1 -ReleaseBranch 'release/v1.15.0' -Complete
    # Phase 2: Konflikte committen, PR erstellen
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ReleaseBranch,

    [string]$SourceBranch = 'master',

    [switch]$Prepare,
    [switch]$Complete
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─── Hilfsfunktionen ────────────────────────────────────────────────────────

function Invoke-Git {
    [CmdletBinding()]
    param([string[]]$Args)
    $output = git @Args 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "git $($Args -join ' ') failed (exit $LASTEXITCODE):`n$output"
    }
    return $output
}

function Invoke-Gh {
    [CmdletBinding()]
    param([string[]]$Args)
    $output = gh @Args 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "gh $($Args -join ' ') failed (exit $LASTEXITCODE):`n$output"
    }
    return $output
}

# ─── Phase 1: Prepare ───────────────────────────────────────────────────────

function Invoke-Prepare {
    [CmdletBinding()]
    param(
        [string]$ReleaseBranch,
        [string]$SourceBranch
    )

    Write-Information "=== Phase 1: Konflikt-Fix vorbereiten ===" -InformationAction Continue
    Write-Information "Release-Branch : ${ReleaseBranch}" -InformationAction Continue
    Write-Information "Source-Branch  : ${SourceBranch}" -InformationAction Continue
    Write-Information '' -InformationAction Continue

    # 1. Fetch
    Write-Information "Fetching origin..." -InformationAction Continue
    Invoke-Git @('fetch', 'origin') | Out-Null

    # 2. Fix-Branch erstellen
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmm'
    $fixBranch = "fix/conflict-${timestamp}"
    Write-Information "Erstelle Branch: ${fixBranch}" -InformationAction Continue
    Invoke-Git @('checkout', '-b', $fixBranch, "origin/${ReleaseBranch}") | Out-Null

    # 3. Merge vorbereiten (kein Commit, kein Fast-Forward)
    Write-Information "Merge vorbereiten: origin/${SourceBranch} → ${fixBranch}..." -InformationAction Continue
    $mergeOutput = git merge "origin/${SourceBranch}" --no-commit --no-ff 2>&1
    # Merge kann mit exit 1 enden wenn Konflikte vorhanden sind — das ist erwartet
    $mergeExitCode = $LASTEXITCODE

    # 4. Konflikt-Dateien auflisten
    $conflictFiles = git diff --name-only --diff-filter=U 2>&1
    $conflictCount = ($conflictFiles | Where-Object { $_ -ne '' }).Count

    if ($mergeExitCode -eq 0 -and $conflictCount -eq 0) {
        Write-Information "Keine Konflikte gefunden — Merge war sauber." -InformationAction Continue
        Write-Information "Abbrechen des Merge-Commits..." -InformationAction Continue
        git merge --abort 2>&1 | Out-Null
        Write-Warning "Merge ohne Konflikte — Invoke-ReleaseConflictFix ist hier nicht erforderlich."
        return
    }

    Write-Information '' -InformationAction Continue
    Write-Information "Konflikt-Dateien (${conflictCount}):" -InformationAction Continue
    foreach ($file in ($conflictFiles | Where-Object { $_ -ne '' })) {
        Write-Information "  $file" -InformationAction Continue
    }

    Write-Information '' -InformationAction Continue
    Write-Information "PHASE 1 COMPLETE — Konflikte in den obigen Dateien beheben, dann -Complete aufrufen:" -InformationAction Continue
    Write-Information "  .\Invoke-ReleaseConflictFix.ps1 -ReleaseBranch '${ReleaseBranch}' -SourceBranch '${SourceBranch}' -Complete" -InformationAction Continue
}

# ─── Phase 2: Complete ──────────────────────────────────────────────────────

function Invoke-Complete {
    [CmdletBinding()]
    param(
        [string]$ReleaseBranch,
        [string]$SourceBranch
    )

    Write-Information "=== Phase 2: Konflikt-Fix abschliessen ===" -InformationAction Continue
    Write-Information '' -InformationAction Continue

    # 1. Alle geaenderten Dateien stagen
    Write-Information "Staging aller Aenderungen..." -InformationAction Continue
    Invoke-Git @('add', '-A') | Out-Null

    # 2. Commit
    $commitMsg = "fix(release): Merge-Konflikte ${ReleaseBranch} <- ${SourceBranch} beheben"
    Write-Information "Commit: ${commitMsg}" -InformationAction Continue
    Invoke-Git @('commit', '-m', $commitMsg) | Out-Null

    # 3. Push
    Write-Information "Pushing Branch..." -InformationAction Continue
    Invoke-Git @('push', '-u', 'origin', 'HEAD') | Out-Null

    # Aktuellen Branch-Namen ermitteln
    $currentBranch = (git branch --show-current 2>&1).Trim()

    # 4. PR erstellen
    $prTitle = "FIX: Merge-Konflikte ${ReleaseBranch} <- ${SourceBranch}"
    $prBody  = "Behebt Merge-Konflikte zwischen ``${ReleaseBranch}`` und ``${SourceBranch}``."

    Write-Information "Erstelle PR: ${prTitle}" -InformationAction Continue
    $prUrl = Invoke-Gh @(
        'pr', 'create',
        '--base', $ReleaseBranch,
        '--title', $prTitle,
        '--body', $prBody
    )

    # 5. Auto-Merge aktivieren
    Write-Information "Aktiviere Auto-Merge..." -InformationAction Continue
    Invoke-Gh @('pr', 'merge', '--auto', '--merge') | Out-Null

    Write-Information '' -InformationAction Continue
    Write-Information "PHASE 2 COMPLETE" -InformationAction Continue
    Write-Information "PR URL: ${prUrl}" -InformationAction Continue

    return $prUrl
}

# ─── Entry Point ────────────────────────────────────────────────────────────

if (-not $Prepare -and -not $Complete) {
    Write-Error @"
Kein Modus angegeben. Bitte -Prepare oder -Complete verwenden.

Usage:
  Phase 1 (Konflikte vorbereiten):
    .\Invoke-ReleaseConflictFix.ps1 -ReleaseBranch '<branch>' [-SourceBranch '<branch>'] -Prepare

  Phase 2 (Konflikte committen und PR erstellen):
    .\Invoke-ReleaseConflictFix.ps1 -ReleaseBranch '<branch>' [-SourceBranch '<branch>'] -Complete
"@
}

if ($Prepare) {
    Invoke-Prepare -ReleaseBranch $ReleaseBranch -SourceBranch $SourceBranch
}

if ($Complete) {
    Invoke-Complete -ReleaseBranch $ReleaseBranch -SourceBranch $SourceBranch
}

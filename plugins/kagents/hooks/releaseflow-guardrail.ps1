#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    K.Agents PreToolUse-Guardrail: Schuetzt den ReleaseFlow-Prozess vor direkten master/main-Merges.

.DESCRIPTION
    Prueft bei 'gh pr create' und 'gh pr merge' Bash-Kommandos, ob der ReleaseFlow-Branching-
    Prozess eingehalten wird. Blockiert direkte master/main-Merges, wenn der Head-Branch kein
    'release/v*' Branch ist.

    ReleaseFlow-Branching-Modell:
        feature/* → dev/vX.Y.Z → release/vX.Y.Z → master

    Nur Promotion-PRs (dev/* → release/*) und Stable-PRs (release/* → master) sind erlaubt.

    Break-Glass: Setze RELEASEFLOW_BYPASS=1 in der Shell, um den Guardrail zu umgehen.

.NOTES
    Defense-in-Depth-Architektur — dieser Hook ist der **proaktive** Layer:

      Layer 1 (proaktiv, LOKAL im Agent-Terminal):
        Dieser Hook. Blockt 'gh pr create'/'gh pr merge' VOR der API-Call,
        verhindert dass ein falscher PR ueberhaupt in GitHub angelegt wird.

      Layer 2 (reaktiv, REMOTE in CI):
        .github/workflows/branch-prefix-guard.yml — markiert PR als failing,
        sobald er in GitHub existiert und eine falsche Prefix-Kombination hat.

      Layer 3 (detective, REMOTE in CI):
        .github/workflows/push-sentinel.yml — protokolliert unerwartete Pushes
        auf geschuetzte Branches, erzeugt Audit-Issue + dispatched Release.

    Gibt JSON via stdout aus, um den Tool-Aufruf in Claude Code zu blockieren:
        {"decision":"block","reason":"..."}
    Exit-Code 0: kein Block (normaler Verlauf oder Bypass).
    Exit-Code 0 + JSON-Block: Tool-Aufruf blockiert, Begruendung an Claude weitergeleitet.
#>

# --- stdin lesen (Claude Code sendet JSON via stdin) ---
. (Join-Path $PSScriptRoot 'HookHelpers.ps1')
$hookData = Read-HookStdin

# Konstanten
$MaxCommandLogLength = 200
$UnknownBaseBranch   = 'master/main (unbekannt)'

# Nur Bash-Tool-Aufrufe pruefen
if ($hookData['tool_name'] -ne 'Bash') { exit 0 }

$toolInput = $hookData['tool_input']
$command = if ($toolInput -is [hashtable] -and $toolInput.ContainsKey('command')) {
    $toolInput['command']
} elseif ($toolInput -is [string]) {
    $toolInput
} else { '' }

if (-not $command) { exit 0 }

# Nur gh pr create/merge pruefen
$isPrCreate = $command -match '\bgh\s+pr\s+create\b'
$isPrMerge  = $command -match '\bgh\s+pr\s+merge\b'
if (-not $isPrCreate -and -not $isPrMerge) { exit 0 }

$cwd = $hookData['cwd']
if (-not $cwd -or -not (Test-Path $cwd)) { exit 0 }

# --- ReleaseFlow-Repo-Detection ---
function Test-IsReleaseFlowRepo {
    [CmdletBinding()]
    param([string]$RepoPath)

    # Marker 1: .releaseflow Datei (Legacy-Marker, wird noch von alten Consumer-Repos gesetzt)
    if (Test-Path (Join-Path $RepoPath '.releaseflow')) { return $true }

    # Marker 2: releaseflow.json
    # ReleaseFlow-App (ab v1/f3f8389) seedet die Config unter .github/releaseflow.json.
    # Der Root-Pfad wird fuer Rueckwaertskompatibilitaet mit aelteren App-Versionen
    # weiter geprueft.
    if (Test-Path (Join-Path $RepoPath '.github' 'releaseflow.json')) { return $true }
    if (Test-Path (Join-Path $RepoPath 'releaseflow.json')) { return $true }

    # Marker 3: action.yml mit K.Actions.ReleaseFlow (nur relevant, wenn das Repo selbst eine Action ist)
    $actionYml = Join-Path $RepoPath 'action.yml'
    if (Test-Path $actionYml) {
        $content = Get-Content $actionYml -Raw -ErrorAction SilentlyContinue
        if ($content -match 'K\.Actions\.ReleaseFlow') { return $true }
    }

    # Marker 4: .github/workflows/*.yml mit ReleaseFlow-Referenz
    $workflowsDir = Join-Path $RepoPath '.github' 'workflows'
    if (Test-Path $workflowsDir) {
        $wfFiles = Get-ChildItem $workflowsDir -Filter '*.yml' -ErrorAction SilentlyContinue
        foreach ($wf in $wfFiles) {
            $content = Get-Content $wf.FullName -Raw -ErrorAction SilentlyContinue
            if ($content -match 'K\.Actions\.ReleaseFlow') { return $true }
        }
    }

    return $false
}

if (-not (Test-IsReleaseFlowRepo -RepoPath $cwd)) { exit 0 }

# --- Break-Glass: RELEASEFLOW_BYPASS=1 ---
if ($env:RELEASEFLOW_BYPASS -eq '1') {
    # Bypass-Nutzung ins Log schreiben (kein Block)
    $logFile = Initialize-LogFile
    @{
        timestamp  = (Get-Date -Format 'o')
        event      = 'releaseflow_guardrail_bypass'
        command    = $(if ($command.Length -gt $MaxCommandLogLength) { $command.Substring(0, $MaxCommandLogLength) + '...' } else { $command })
        cwd        = $cwd
        session_id = $hookData['session_id']
    } | ConvertTo-Json -Compress | Add-Content -Path $logFile -Encoding utf8
    exit 0
}

# --- Aktuellen Git-Branch ermitteln ---
$currentBranch = try {
    $result = & git -C $cwd rev-parse --abbrev-ref HEAD 2>$null
    if ($LASTEXITCODE -eq 0) { $result.Trim() } else { '' }
} catch { '' }

$masterPattern  = '^(master|main)$'
$releasePattern = '^release/v'
$devPattern     = '^dev/v'

# --- Hilfsfunktion: Block-Antwort schreiben ---
function Write-GuardrailBlock {
    [CmdletBinding()]
    param([string]$Reason)
    @{ decision = 'block'; reason = $Reason } | ConvertTo-Json -Compress | Write-Output
}

# =========================================================
# Check 0: git push auf feature/* oder fix/* → aktiver Train erforderlich
# =========================================================
$isGitPush = $command -match '\bgit\s+push\b'
if ($isGitPush -and $currentBranch -match '^(feature|fix)/') {
    $repoSlug = try {
        $result = & git -C $cwd remote get-url origin 2>$null
        if ($LASTEXITCODE -eq 0 -and $result -match 'github\.com[:/](.+?)(?:\.git)?$') {
            $Matches[1]
        } else { '' }
    } catch { '' }

    if ($repoSlug) {
        $draftCount = try {
            $result = & gh api "repos/$repoSlug/releases" `
                --jq '[.[] | select(.draft == true and (.tag_name | test("^v[0-9]+[.][0-9]+[.][0-9]+$")))] | length' `
                2>$null
            if ($LASTEXITCODE -eq 0) { [int]($result.Trim()) } else { -1 }
        } catch { -1 }

        if ($draftCount -eq 0) {
            Write-GuardrailBlock -Reason @"
⛔ ReleaseFlow-Guardrail: Kein aktiver Train — Push blockiert

Branch '$currentBranch' kann nicht gepusht werden, da kein aktiver ReleaseFlow-Train existiert.
Ohne Train schlägt auto-pr.yml mit "Kein aktiver Draft Release Intent gefunden" fehl.

Lösung:
  1. plan-release.yml dispatchen:
       gh workflow run plan-release.yml --repo $repoSlug -f target_version=X.Y.Z
  2. Warten bis Draft-Release erstellt ist (ca. 30s)
  3. Dann erneut pushen

Break-Glass (falls beabsichtigt):
  Setze RELEASEFLOW_BYPASS=1 und starte den Agenten erneut.
"@
            exit 0
        }
    }
}

# =========================================================
# Check 1: gh pr create
# =========================================================
if ($isPrCreate) {
    # --base Flag aus dem Kommando extrahieren
    $baseMatch  = [regex]::Match($command, '--base\s+[''"]?([^\s''"]+)[''"]?')
    $baseBranch = if ($baseMatch.Success) { $baseMatch.Groups[1].Value } else { '' }

    if ($baseBranch -match $masterPattern) {
        # Erlaubt: release/v* → master (Stable-PR)
        if ($currentBranch -match $releasePattern) { exit 0 }

        Write-GuardrailBlock -Reason @"
⛔ ReleaseFlow-Guardrail: Direkter $baseBranch-Merge blockiert

Der Branch '$currentBranch' darf nicht direkt auf '$baseBranch' mergen.

ReleaseFlow-Branching-Modell:
  feature/* oder fix/*  →  dev/vX.Y.Z  →  release/vX.Y.Z  →  master

Erlaubte PR-Targets auf master/main:
  • release/vX.Y.Z  →  master   (Stable-Release)

Aktueller Branch: $currentBranch

Break-Glass (falls beabsichtigt):
  Setze `$env:RELEASEFLOW_BYPASS = '1'` und starte den Agenten erneut.
"@
        exit 0
    }

    # Kein --base angegeben und kein erlaubter Branch → warnen
    if (-not $baseBranch) {
        if ($currentBranch -match $releasePattern -or $currentBranch -match $devPattern) {
            exit 0
        }
        Write-GuardrailBlock -Reason @"
⚠️  ReleaseFlow-Guardrail: Kein --base angegeben

Bei 'gh pr create' ohne --base wird der Default-Branch (meist master/main) als Ziel verwendet.
Das wuerde den ReleaseFlow-Prozess umgehen.

ReleaseFlow-Branching-Modell:
  feature/* oder fix/*  →  dev/vX.Y.Z  →  release/vX.Y.Z  →  master

Bitte --base explizit angeben:
  • gh pr create --base dev/vX.Y.Z   (Feature/Bugfix → Alpha)
  • gh pr create --base release/vX.Y.Z  (Freeze-PR oder Beta-Fix)
  • gh pr create --base master          (nur von release/v*)

Aktueller Branch: $currentBranch

Break-Glass (falls beabsichtigt):
  Setze `$env:RELEASEFLOW_BYPASS = '1'` und starte den Agenten erneut.
"@
        exit 0
    }
}

# =========================================================
# Check 2: gh pr merge
# =========================================================
if ($isPrMerge) {
    # Erlaubt: release/v* darf immer mergen
    if ($currentBranch -match $releasePattern) { exit 0 }

    # PR-Nummer aus Kommando lesen und Base-Branch via gh abfragen
    # gh muss im Repo-Verzeichnis (cwd) ausgefuehrt werden, da kein --repo-Flag bekannt ist
    $baseBranch = ''
    $prNumberMatch = [regex]::Match($command, '\bgh\s+pr\s+merge\s+(\d+)')
    try {
        Push-Location $cwd -ErrorAction Stop
        if ($prNumberMatch.Success) {
            $prNumber = $prNumberMatch.Groups[1].Value
            # 2>$null: gh-Fehler (kein Auth, PR nicht gefunden) werden bewusst ignoriert
            $ghResult = & gh pr view $prNumber --json baseRefName --jq '.baseRefName' 2>$null
            if ($LASTEXITCODE -eq 0) { $baseBranch = $ghResult.Trim() }
        } else {
            # Kein PR-Nummer → PR des aktuellen Branches ermitteln
            # 2>$null: gh-Fehler (kein offener PR) werden bewusst ignoriert
            $ghResult = & gh pr view --json baseRefName --jq '.baseRefName' 2>$null
            if ($LASTEXITCODE -eq 0) { $baseBranch = $ghResult.Trim() }
        }
    } catch { $baseBranch = '' } finally { Pop-Location }

    # Nur blockieren, wenn Base-Branch master/main ist (oder nicht ermittelbar + kein release-Branch)
    $shouldBlock = $baseBranch -match $masterPattern
    if (-not $shouldBlock -and -not $baseBranch -and -not ($currentBranch -match $releasePattern)) {
        # Base unbekannt und nicht auf release/* → konservativ blockieren
        $shouldBlock = $true
        $baseBranch  = $UnknownBaseBranch
    }

    if ($shouldBlock) {
        Write-GuardrailBlock -Reason @"
⛔ ReleaseFlow-Guardrail: gh pr merge auf $baseBranch blockiert

Nur 'release/vX.Y.Z' Branches duerfen direkt auf master/main gemergt werden (Stable-Release).

ReleaseFlow-Branching-Modell:
  feature/* oder fix/*  →  dev/vX.Y.Z  →  release/vX.Y.Z  →  master

Aktueller Branch: $currentBranch
PR-Target:        $baseBranch

Break-Glass (falls beabsichtigt):
  Setze `$env:RELEASEFLOW_BYPASS = '1'` und starte den Agenten erneut.
"@
        exit 0
    }
}

exit 0

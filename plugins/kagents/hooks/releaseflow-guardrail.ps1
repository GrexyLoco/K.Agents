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
    Gibt JSON via stdout aus, um den Tool-Aufruf in Claude Code zu blockieren:
        {"decision":"block","reason":"..."}
    Exit-Code 0: kein Block (normaler Verlauf oder Bypass).
    Exit-Code 0 + JSON-Block: Tool-Aufruf blockiert, Begruendung an Claude weitergeleitet.
#>

# --- stdin lesen (Claude Code sendet JSON via stdin) ---
$rawInput = try { [Console]::In.ReadToEnd() } catch { '' }
$hookData = if ($rawInput.Trim()) {
    try { $rawInput | ConvertFrom-Json -AsHashtable } catch { @{} }
} else { @{} }

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

    # Marker 1: .releaseflow Datei
    if (Test-Path (Join-Path $RepoPath '.releaseflow')) { return $true }

    # Marker 2: releaseflow.json
    if (Test-Path (Join-Path $RepoPath 'releaseflow.json')) { return $true }

    # Marker 3: action.yml mit K.Actions.ReleaseFlow
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
    $pluginRoot = if ($env:CLAUDE_PLUGIN_ROOT) {
        $env:CLAUDE_PLUGIN_ROOT
    } else {
        Split-Path -Parent $PSScriptRoot
    }
    $logDir  = Join-Path $pluginRoot 'logs'
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $logFile = Join-Path $logDir "$(Get-Date -Format 'yyyy-MM-dd').jsonl"
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

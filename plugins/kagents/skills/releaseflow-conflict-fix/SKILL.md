---
name: releaseflow-conflict-fix
description: "ReleaseFlow-spezifischen Merge-Konflikt-Workflow ausführen — fix/-Branch,
  Konflikt-Behebung, PR mit auto-merge. LOAD WHEN: PR zeigt DIRTY-Status,
  'not mergeable', Merge-Konflikte zwischen release/* und master."
---

# ReleaseFlow Merge-Konflikt-Fix

Zweistufiger Workflow — NIEMALS direkt auf `release/*` pushen.

## Phase 1: Konflikte identifizieren

```powershell
& "${env:CLAUDE_PLUGIN_ROOT}/tools/releaseflow/Invoke-ReleaseConflictFix.ps1" `
    -ReleaseBranch "release/vX.Y.Z" `
    -Prepare
```

Das Script erstellt einen `fix/conflict-*`-Branch und zeigt die Konflikt-Dateien.

## Phase 2: Konflikte beheben und PR erstellen

1. Konflikt-Dateien mit Edit-Tool lösen
2. Dann:
```powershell
& "${env:CLAUDE_PLUGIN_ROOT}/tools/releaseflow/Invoke-ReleaseConflictFix.ps1" `
    -ReleaseBranch "release/vX.Y.Z" `
    -Complete
```

Das Script committet, pusht und erstellt einen PR mit Auto-Merge.

## Anti-Pattern ⚠️

**NIEMALS:** `git push origin release/*` — release-Branches sind OFF-LIMITS für direkte Pushes.

---
name: releaseflow-conflict-fix
description: "ReleaseFlow-spezifischen Merge-Konflikt-Workflow ausführen — fix/-Branch,
  Konflikt-Behebung, PR mit auto-merge. LOAD WHEN: PR zeigt DIRTY-Status,
  'not mergeable', Merge-Konflikte zwischen release/* und master."
---

# 1. ReleaseFlow Merge-Konflikt-Fix

Zweistufiger Workflow — NIEMALS direkt auf `release/*` pushen.

## 1.1 Phase 1: Konflikte identifizieren

```powershell
& "${env:CLAUDE_PLUGIN_ROOT}/tools/releaseflow/Invoke-ReleaseConflictFix.ps1" `
    -ReleaseBranch "release/vX.Y.Z" `
    -Prepare
```

Das Script erstellt einen `fix/conflict-*`-Branch und zeigt die Konflikt-Dateien.

## 1.2 Phase 2: Konflikte beheben und PR erstellen

1. Konflikt-Dateien mit Edit-Tool lösen
2. Dann:
```powershell
& "${env:CLAUDE_PLUGIN_ROOT}/tools/releaseflow/Invoke-ReleaseConflictFix.ps1" `
    -ReleaseBranch "release/vX.Y.Z" `
    -Complete
```

Das Script committet, pusht und erstellt einen PR mit Auto-Merge.

## 1.3 Anti-Pattern ⚠️

**NIEMALS:** `git push origin release/*` — release-Branches sind OFF-LIMITS für direkte Pushes.

---
name: releaseflow-train-status
description: "Aktuellen ReleaseFlow-Train-Status abfragen — Phase, erlaubte Branches,
  Milestone, blockierende Issues. ALWAYS LOAD WHEN: Fragen nach aktuellem Train,
  welche Phase aktiv ist, ob ein Push erlaubt ist, Freeze-Readiness."
---

# 1. ReleaseFlow Train-Status

Führe aus:
```powershell
& "${env:CLAUDE_PLUGIN_ROOT}/tools/releaseflow/Get-ReleaseTrain.ps1"
```

Interpretiere den Output:

| Phase | Bedeutung | Erlaubte Branches | Nächster Schritt |
|-------|-----------|-------------------|-----------------|
| `None` | Kein Train aktiv | — | `plan-release.yml` dispatchen |
| `Alpha` | Alpha-Phase | `feature/*, fix/*` → `dev/vX.Y.Z` | Feature-Branches mergen |
| `Freeze` | Feature-Freeze | nur `fix/*` → `release/vX.Y.Z` | Nur Bugfixes |
| `Beta` | Beta-Phase | nur `fix/*` → `release/vX.Y.Z` | Nur Bugfixes |
| `Stable` | Kein aktiver Train | — | Neues `plan-release` starten |

**BlockingIssues vorhanden?** → Freeze noch nicht möglich (alle Issues brauchen Label `phase:in-alpha`).

**PushAllowed = NO?** → Ursache aus `Phase` und `BlockingIssues` lesen, korrigieren, erneut prüfen.

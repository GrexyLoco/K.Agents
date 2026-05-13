---
name: releaseflow-push
description: "Sicherer git push für feature/* oder fix/* mit ReleaseFlow-Validierung.
  ALWAYS LOAD WHEN: vor jedem git push auf feature/* oder fix/*."
---

# ReleaseFlow-sicherer Push

**IMMER vor `git push` auf `feature/*` oder `fix/*` ausführen.**

## Schritt 1: Train-Status prüfen

```powershell
$train = & "${env:CLAUDE_PLUGIN_ROOT}/tools/releaseflow/Get-ReleaseTrain.ps1"
```

## Schritt 2: Entscheidung

| `PushAllowed` | `Phase` | Aktion |
|---------------|---------|--------|
| `YES` | Alpha | `git push -u origin <branch>` — PR geht nach `dev/vX.Y.Z` |
| `YES` | Beta | `git push -u origin <branch>` — nur `fix/*`, PR geht nach `release/vX.Y.Z` |
| `NO` | Freeze | Warten — nur Bugfixes via `fix/*` erlaubt |
| `NO` | Stable/None | Neuen Train starten via `plan-release.yml` |

## Schritt 3: Push ausführen

```powershell
git push -u origin <branch-name>
```

**Erlaubte Branch-Prefixes:** `feature/*` und `fix/*` — andere Prefixes werden vom CI-Guard abgelehnt.

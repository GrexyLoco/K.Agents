---
name: releaseflow-domain
description: K.Actions.ReleaseFlow Domänenwissen – Phasen, Guardrails, Branching, Tagging, Freeze-Lifecycle. Nutze diesen Skill bei allem was mit Releases, Branches, Versionierung oder dem Release-Prozess zu tun hat.
---

# ReleaseFlow – Domänenwissen

## Überblick

K.Actions.ReleaseFlow ist eine GitHub Composite Action + PowerShell-Modul für automatisierte Release-Orchestrierung. Single Entry Point: `New-Release` erkennt die Phase automatisch aus dem Branch-Kontext.

**Abhängigkeit:** K.PSGallery.Smartagr (Tagging-Backend, separates Modul auf PSGallery)

## Branching-Modell

```
feature/* ──→ dev/vX.Y.Z ──→ release/vX.Y.Z ──→ main
fix/*     ──→ dev/vX.Y.Z     fix/* ──→ release/vX.Y.Z
                                                    │
                                         Backflow PRs ──→ offene dev/* Branches
```

## Phase Detection (automatisch aus PR-Kontext)

| Source Branch | Target Branch | Phase | Aktion |
|---------------|---------------|-------|--------|
| `feature/*` | `dev/vX.Y.Z` | Alpha | Alpha-Tag + GitHub Release (prerelease) |
| `fix/*` | `dev/vX.Y.Z` | Alpha | Alpha-Tag + GitHub Release (prerelease) |
| `dev/vX.Y.Z` | `release/vX.Y.Z` | Freeze | Freeze-Tag + Promotion-PR |
| `fix/*` | `release/vX.Y.Z` | Beta | Beta-Tag + GitHub Release (prerelease) |
| `release/vX.Y.Z` | `main` | Stable | Draft veröffentlichen + Smart Tags + Backflow PRs |

## Guardrails (G1–G5)

| ID | Name | Prüft | Blockiert |
|----|------|-------|-----------|
| **G1** | Dev-Gate | Draft-Intent existiert für Zielversion | Merge ohne Release-Plan |
| **G2** | Freeze-Gate | Release-Branch existiert → keine neuen Features | Feature-PRs nach Freeze |
| **G3** | Beta-Gate | Nur fix/* Commits seit Freeze | Nicht-autorisierte Änderungen |
| **G4** | Stable-Gate | CI grün, alle Betas erfolgreich | Broken Release |
| **G5** | Feature-Freeze-Enforcement | Freeze-Tag aktiv → nur Bugfixes | Feature-PRs während Freeze |

**Fail-Fast:** Orchestrator bricht beim ersten fehlgeschlagenen Guardrail ab.

## Release-Train-Planung (PO Dispatch)

`New-ReleaseTrain -TargetVersion "2.0.0"` erstellt atomar:
1. Draft-Release (Intent) mit Tag `v2.0.0`
2. Dev-Branch `dev/v2.0.0` vom letzten Stable-Tag

**PO-Guardrails:** PD-1 (Duplikat-Intent), PD-2 (Tag existiert), PD-3 (Branch existiert), PD-4 (Base existiert), PD-5 (Downgrade-Schutz)

## Tagging-Strategie

| Tag-Typ | Format | Beispiel | Erstellt von |
|---------|--------|----------|-------------|
| Alpha | `vX.Y.Z-alphaN` | `v1.2.0-alpha3` | New-AlphaRelease |
| Beta | `vX.Y.Z-betaN` | `v1.2.0-beta1` | New-BetaRelease |
| Freeze-Marker | `vX.Y.Z-freeze` | `v1.2.0-freeze` | New-FreezeRelease |
| Stable | `vX.Y.Z` | `v1.2.0` | Publish-StableRelease |
| Smart (Major) | `vX` | `v1` | K.PSGallery.Smartagr |
| Smart (Minor) | `vX.Y` | `v1.2` | K.PSGallery.Smartagr |
| Latest | `latest` | `latest` | K.PSGallery.Smartagr |

## Single-Freeze-Policy

Nur ein Release-Train darf gleichzeitig eingefroren sein.

**Freeze-Lifecycle:**
1. Freeze-Dispatch auf `dev/vX.Y.Z` → Tag `vX.Y.Z-freeze` gesetzt
2. G5 blockiert `feature/*`, G3 erlaubt nur `fix/*`
3. Stable Release → Freeze-Tag gelöscht, Draft veröffentlicht, Smart Tags, Backflow PRs

## Token-Strategie

**Immer GitHub App Token** (nie PATs):
- Scoped Permissions pro Repo
- Audit Trail als `k-releaseflow-bot[bot]`
- Ruleset Bypass als Integration-Actor
- Downstream-Trigger für `on: push` Workflows

```yaml
- uses: actions/create-github-app-token@v2
  id: app-token
  with:
    app-id: ${{ vars.RELEASEFLOW_APP_ID }}
    private-key: ${{ secrets.RELEASEFLOW_APP_PRIVATE_KEY }}
```

## Consumer-Onboarding

1. GitHub App installieren → Rulesets werden automatisch deployed (4 Stück)
2. `releaseflow.json` wird auto-seeded
3. Release-Workflow einrichten (siehe `examples/`)
4. `New-ReleaseTrain` für ersten Release-Train

## Outputs der Action

| Output | Beschreibung | Verfügbar bei |
|--------|-------------|---------------|
| `tag` | Erstellter Git-Tag | Alle Phasen |
| `version` | SemVer ohne v-Prefix | Alle Phasen |
| `phase` | alpha/beta/stable/freeze | Alle Phasen |
| `release-url` | URL des GitHub Release | Alle Phasen |
| `is-prerelease` | true bei alpha/beta | Alle Phasen |
| `backflow-prs` | PR-URLs (komma-separiert) | Nur Stable |
| `error-message` | Fehlermeldung bei Guardrail-Fehler | Bei Fehler |

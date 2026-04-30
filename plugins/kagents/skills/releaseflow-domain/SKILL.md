---
name: releaseflow-domain
description: "K.Actions.ReleaseFlow process \u2014 branching model (feature \u2192 dev \u2192 release \u2192 main), phases (Alpha, Freeze, Beta, Stable), guardrails G1\u2013G5, KI-Verhaltensbeschr\u00e4nkungen (was KI darf/nicht darf), release-train planning, feature-freeze enforcement, pre-release tagging, smart tags. USE FOR: understanding ReleaseFlow branching, planning releases, checking phase rules, guardrails and AI behavior constraints. DO NOT USE FOR: changelog/tag creation (use release-management) or modifying ReleaseFlow code (use releaseflow-coding-patterns)."
---

# ReleaseFlow – Domänenwissen

## Überblick

K.Actions.ReleaseFlow ist eine GitHub App + Composite Action + PowerShell-Modul für automatisierte Release-Orchestrierung. Phase-Detection erfolgt automatisch aus dem Branch-Kontext, verteilt auf separate Workflow-YMLs (Option A / getrennte Workflows, empfohlen).

**Abhängigkeit:** K.PSGallery.Smartagr (Tagging-Backend, separates Modul auf PSGallery)

**App-Version-Referenz:** Das Action-Repo ist privat (`GrexyLoco/K.Actions.ReleaseFlow@v1`). Consumer beziehen die Action per Cross-Repo-Checkout mit App-Token (siehe `releaseflow-coding-patterns`).

## Branching-Modell

```
feature/* ──→ dev/vX.Y.Z ──→ release/vX.Y.Z ──→ master/main
fix/*     ──→ dev/vX.Y.Z     fix/* ──→ release/vX.Y.Z
                                                    │
                                         Backflow PRs ──→ offene dev/* + release/* Branches
```

## Workflow-Architektur (getrennte YMLs pro Phase)

| Workflow | Trigger | Zweck |
|----------|---------|-------|
| `alpha-release.yml` | PR-close auf `dev/v*` (head=feature/* oder fix/*) + `workflow_dispatch` (Break-Glass) | Alpha-Tag + Pre-Release + `phase:in-alpha`-Label |
| `beta-release.yml` | Push auf `release/v*` (paths-ignore: `**/*.md`, `docs/**`) | Beta-Tag + Pre-Release + `phase:in-beta`-Label |
| `release.yml` | PR-close auf `main`, `dev/v*`, `release/v*` | Phase-Detection + Stable-Promo + Backflow |
| `plan-release.yml` | `workflow_dispatch` mit `target_version` | Draft-Intent + Milestone + `dev/v*`-Branch atomar |
| `auto-pr.yml` | Push auf `fix/**`, `feature/**` | Auto-PR gegen aktiven Train + Milestone-Binding |
| `branch-prefix-guard.yml` | PR-Events auf `dev/v*`, `release/v*`, `master`, `main` | Policy-Enforcement (erlaubte Prefixes) |
| `push-sentinel.yml` | Push auf `dev/v*`, `release/v*`, `master`, `main` | Detective-Control (unerwartete Pushes → Audit-Issue) |

## Phase Detection (automatisch aus PR-Kontext)

| Source Branch | Target Branch | Phase | Aktion |
|---------------|---------------|-------|--------|
| `feature/*` | `dev/vX.Y.Z` | Alpha | Alpha-Tag (`vX.Y.Z-alphaN`) + Pre-Release |
| `fix/*` | `dev/vX.Y.Z` | Alpha | Alpha-Tag + Pre-Release |
| `dev/vX.Y.Z` | `release/vX.Y.Z` | Freeze | Freeze-Tag (`vX.Y.Z-freeze`) gesetzt |
| `fix/*` | `release/vX.Y.Z` | Beta | Beta-Tag (`vX.Y.Z-betaN`) + Pre-Release |
| `release/vX.Y.Z` | `master`/`main` | Stable | Draft veröffentlichen + Smart Tags + Backflow PRs |

### Phase-Detection durch `auto-pr.yml`

`auto-pr.yml` wählt den Target-Branch basierend auf:
- **Draft-Intent** (`gh api releases` → Draft mit `vX.Y.Z` Tag)
- **`release/vX.Y.Z`-Branch existiert?** → Phase=beta, sonst Phase=alpha
- **Branch-Typ + Phase-Mapping:**
  - `feature/*` → immer `dev/vX.Y.Z` (auch in Beta)
  - `fix/*` in Alpha → `dev/vX.Y.Z`
  - `fix/*` in Beta → `release/vX.Y.Z`

⚠️ **Stale release/v\*-Branches täuschen Beta-Phase vor.** Wenn `release/vX.Y.Z` vor dem Freeze existiert, routet `auto-pr.yml` alle `fix/*`-PRs fälschlich dorthin.

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
| Alpha | `vX.Y.Z-alphaN` (ohne Punkt) | `v1.2.0-alpha3` | New-AlphaRelease |
| Beta | `vX.Y.Z-betaN` (ohne Punkt) | `v1.2.0-beta1` | New-BetaRelease |
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
- Audit Trail als `k-releaseflow[bot]` (wichtig für `push_sentinel.yml` Allowlist)
- Ruleset Bypass als Integration-Actor
- Downstream-Trigger für `on: push` Workflows

```yaml
- uses: actions/create-github-app-token@v3
  id: app-token
  with:
    client-id: ${{ vars.RELEASEFLOW_APP_ID }}
    private-key: ${{ secrets.RELEASEFLOW_APP_PRIVATE_KEY }}
    owner: <owner>
    repositories: >
      ${{ github.event.repository.name }},K.Actions.ReleaseFlow
```

Der zweite Repo (`K.Actions.ReleaseFlow`) im `repositories`-Scope ist für den Cross-Repo-Checkout der privaten Action nötig (#390).

## Consumer-Onboarding

1. GitHub App installieren → **4 Rulesets** werden automatisch deployed: `dev`, `release`, `main`, `tags`
2. Config wird unter **`.github/releaseflow.json`** auto-seeded (`statusCheck.enabled`, `statusCheck.context`, `push_sentinel.allowed_bots`)
3. **7 Workflows** werden ins Consumer-Repo geschrieben: `alpha-release.yml`, `beta-release.yml`, `release.yml`, `plan-release.yml`, `auto-pr.yml`, `branch-prefix-guard.yml`, `push-sentinel.yml`. Alte consumer-owned Workflows landen in `.github/workflows/_releaseflow_backup/consumer-owned/`
4. Consumer setzt eigene `repository_dispatch`-Handler für Plugin-Metadata/Deployments (siehe Consumer-Hook-Pattern unten)
5. Ersten Train via `Plan Release (PO Dispatch)` Workflow anlegen

## Consumer-Hook-Pattern

Die Phasen-Workflows dispatchen nach jedem Release ein `repository_dispatch` Event mit `client_payload`. Consumer-Workflows reagieren darauf — typisch für:
- Plugin-Metadata-Updates (JSON-Bump)
- Deployments (Nuget-Push, Container-Image, Website-Deploy)
- Notifications (Slack, Teams, Discord)

| Event-Type | Dispatched von | Payload |
|------------|----------------|---------|
| `releaseflow-alpha` | `alpha-release.yml` | `version`, `tag`, `release-url`, `phase` |
| `releaseflow-beta` | `beta-release.yml` | dito |
| `releaseflow-{phase}` | `release.yml` | dito, phase ∈ {alpha, beta, stable} |
| `releaseflow-plan` | `plan-release.yml` | `version`, `intent-url`, `phase` |
| `releaseflow-auto-pr` | `auto-pr.yml` | `pr-url`, `branch`, `phase` |

```yaml
# Consumer-Workflow
on:
  repository_dispatch:
    types: [releaseflow-stable]

jobs:
  deploy:
    if: github.event.action == 'releaseflow-stable'
    steps:
      - run: echo "Deploying ${{ github.event.client_payload.tag }}"
```

## Phase-Labels

`alpha-release.yml` und `beta-release.yml` parsen Closing-Keywords (`closes #N`, `fixes #N`, etc.) aus PR-Bodies und labeln die Issues:
- `phase:in-alpha` nach Alpha-Merge
- `phase:in-beta` nach Beta-Release

Issues bleiben **open** bis zum Stable-Merge — dann Bulk-Close via GitHub-Closing-Keywords im Stable-Promo-PR.

## Milestone-Binding

`auto-pr.yml` erkennt Issue-Nummern aus Branch-Namen-Pattern `fix/N-slug` bzw. `feature/N-slug` und ruft `action: resolve-milestone` auf → Issue wird automatisch an den aktiven Train-Milestone gebunden (#200).

## Branch-Prefix-Policy (enforced durch `branch-prefix-guard.yml`)

| Head | Base | Erlaubt? |
|------|------|----------|
| `feature/*`, `fix/*` | `dev/v*`, `release/v*` | ✅ Code-PR |
| `dev/v*` | `release/v*` | ✅ Promotion (Freeze) |
| `release/v*` | `master`, `main` | ✅ Stable-PR |
| `master`, `main` | `dev/v*`, `release/v*` | ✅ Backflow |
| alles andere | — | ❌ Block |

Der **PR-Titel-Typ** (`FEAT:`, `FIX:`, `DOC:`, `REFACTOR:`) ist unabhängig vom Branch-Prefix.

## Push-Sentinel (Defense-in-Depth)

`push-sentinel.yml` klassifiziert jeden Push auf geschützte Branches:
- `pr-merge` — erkannte PR-Merge-Commits (silent)
- `bot-commit` — Allowlisted Bots (`k-releaseflow[bot]` default) oder `[skip ci]`-Commits (silent)
- `bot-commit-foreign` — Bot nicht in `push_sentinel.allowed_bots` → Audit-Issue
- `unknown` → Audit-Issue + Dispatch des Phase-Workflows

Allowlist konfigurierbar in `.github/releaseflow.json`:
```json
{
  "push_sentinel": {
    "allowed_bots": ["k-releaseflow[bot]", "dependabot[bot]"]
  }
}
```

## Action-Interface

`./.releaseflow` Composite Action akzeptiert:
- `action`: `release` (Default, Phase-Detection) | `plan-release` | `resolve-milestone`
- `github-token`: App-Token (Pflicht)
- `target-version` (nur für `plan-release`)
- `base` (nur für `plan-release`, default `latest-stable`)
- `issue-number` + `branch-name` (nur für `resolve-milestone`)

## Outputs der Action

| Output | Beschreibung | Verfügbar bei |
|--------|-------------|---------------|
| `tag` | Erstellter Git-Tag | release |
| `version` | SemVer ohne v-Prefix | release |
| `phase` | alpha/beta/stable/freeze | release |
| `release-url` | URL des GitHub Release | release |
| `release-created` | `true`/`false` — Tag neu erstellt? | release |
| `is-prerelease` | true bei alpha/beta | release |
| `backflow-prs` | PR-URLs (komma-separiert) | Nur Stable |
| `dev-branch` | erstellter dev/v*-Branch | plan-release |
| `intent-url` | URL des Draft-Release | plan-release |
| `base-commit` | Commit-SHA des Train-Start | plan-release |
| `milestone-url` | URL des Milestones | plan-release |
| `milestone-title` | Milestone-Titel | plan-release |
| `error-message` | Fehlermeldung bei Guardrail-Fehler | Bei Fehler |

## KI-Verhalten im ReleaseFlow-Kontext

### Was ReleaseFlow AUTOMATISCH erledigt (KI nicht eingreifen!)

| Aktion | Trigger | Wer |
|--------|---------|-----|
| Alpha-Tag + Pre-Release | PR-Merge auf `dev/v*` | `k-releaseflow[bot]` |
| Freeze-Tag | Merge `dev/v*` → `release/v*` | `k-releaseflow[bot]` |
| Beta-Tag + Pre-Release | PR-Merge `fix/*` → `release/v*` | `k-releaseflow[bot]` |
| Stable-Release | Merge `release/v*` → `master` | `k-releaseflow[bot]` |
| Smart Tags (vX, vX.Y, latest) | Stable-Merge | K.PSGallery.Smartagr |
| Backflow PRs | Stable-Merge | `k-releaseflow[bot]` |
| Plugin-JSON-Bump | Stable-Release | `consumer-hooks.yml` |
| Dev-Branch + Milestone | `plan-release.yml` Dispatch | `k-releaseflow[bot]` |
| Auto-PR auf aktiven Train | Push auf `feature/**` oder `fix/**` | `auto-pr.yml` |

### Train-Status prüfen (konkrete Befehle)

```powershell
# Aktive Releases / Phase bestimmen
gh release list --repo OWNER/REPO --limit 10

# Draft-Intent (aktiver Train) ermitteln
gh api repos/OWNER/REPO/releases --jq '.[] | select(.draft==true) | .tag_name'

# Freeze-Status prüfen (Tag vorhanden?)
gh api repos/OWNER/REPO/git/refs/tags --jq '.[].ref' | grep freeze

# Offene PRs im Train
gh pr list --repo OWNER/REPO --state open

# CI-Status letzter Workflows
gh run list --repo OWNER/REPO --limit 5
```

**Phase erkennen:**

| Letzter Tag-Suffix | Aktuelle Phase |
|--------------------|----------------|
| `-alphaN` | Alpha läuft |
| `-freeze` | Freeze abgeschlossen, Beta bereit |
| `-betaN` | Beta läuft |
| (clean, z.B. `v1.2.0`) | Stable — kein aktiver Train |

### Was die KI TUN DARF

| Aktion | Befehl |
|--------|--------|
| Status überwachen | `gh release list`, `gh run list` |
| Phase bestimmen | Tag-Suffix analysieren |
| Guardrail-Fehler fixen | Fix-Commit auf bestehendem Branch |
| PR erstellen (`feature/*`, `fix/*`) | `gh pr create --base dev/vX.Y.Z` |
| Auf Befehl Promo-PR erstellen | `gh pr create --base release/vX.Y.Z --head dev/vX.Y.Z` |
| Anomalien melden | Audit-Issue öffnen, User informieren |

**Polling-Intervalle:**
- CI-Status nach Commit: Warten ~2 Minuten, dann prüfen — Intervall ≥ 5 Minuten
- Phase-Progression nach Merge: Warten ~1 Minute, dann prüfen — Intervall ≥ 3 Minuten

### Was die KI NIEMALS tun darf

| Verbotene Aktion | Konsequenz |
|------------------|------------|
| Manuell Tags erstellen (`git tag`, `gh release create`) | Korrumpiert Tag-Sequenz, bricht Smart Tags |
| Promo-PR (dev→release oder release→master) ohne expliziten Befehl | Überspringt Phase-Gate |
| Direkt auf `master`, `release/*` pushen | Push-Sentinel → Audit-Issue |
| PR von `feature/*` auf `release/v*` | G2/G3-Verletzung + Branch-Prefix-Guard-Block |
| Branch ohne Prefix `feature/` oder `fix/` erstellen | branch-prefix-guard blockiert PR |
| Ohne aktiven Train (kein Draft-Intent) Features committen | G1-Verletzung |

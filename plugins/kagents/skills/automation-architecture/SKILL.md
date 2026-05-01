---
name: automation-architecture
description: CI/CD Pipeline-Architektur, PowerShell Module, GitHub Packages, Release-Strategien, ReleaseFlow
---

# Automation-Architecture Skill

## Übersicht

Dieses Skill behandelt CI/CD-Pipeline-Design, PowerShell Module-Struktur, GitHub Packages Publishing und Release-Strategien mit K.Actions.ReleaseFlow.

## GitHub Actions Workflow-Architektur

### Reusable Workflows vs. Composite Actions

| Aspekt | Reusable Workflows | Composite Actions |
|--------|-------------------|-------------------|
| **Umfang** | Komplette Workflows | Einzelne Schritte |
| **Trigger** | `workflow_call` + Standard | Als `run` Step |
| **Matrix-Support** | Ja | Nein |
| **Komplexität** | Höher | Niedriger |
| **Wiederverwendung** | Job-Level | Step-Level |

**Empfehlung:** Reusable Workflows für Multi-Job-Pipelines, Composite Actions für Utility-Schritte.

### Matrix-Builds für Multi-Plattform

```yaml
strategy:
  matrix:
    os: [ubuntu-latest, windows-latest, macos-latest]
    dotnet-version: [8.0, 9.0, 10.0]
  fail-fast: false
```

Nutze für .NET auf Windows/Linux/macOS, um Plattform-spezifische Bugs früh zu finden.

### Caching-Strategien
- **NuGet:** `~/.nuget/packages` mit `nuget-version`
- **dotnet restore:** `global.json` als Cache-Key
- **Build-Artefakte:** Nur zwischen abhängigen Jobs
- **Docker Layers:** Für Container-Builds

### Workflow-Trigger-Design
- **push:** Nur auf Main/Release-Branches
- **pull_request:** Auf alle Branches, read-only Secrets
- **release:** Nach Release-Erstellung
- **schedule:** Nächtliche Security-Scans
- **workflow_dispatch:** Manuelle Trigger mit Parametern

### Secret Management
- **GitHub App Token:** Scoped Permissions, Audit Trail, Ruleset Bypass
- **OIDC-basierte Authentifizierung:** Für Cloud-Services
- **Secrets minimal:** Nur wo nötig, masken in Logs
- **PATs vermeiden:** Legacy, unsicher für Automation

### Workflow Concurrency

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

Stoppe alte Runs wenn neue auf gleicher Branch starten.

## K.Actions.ReleaseFlow Architektur

### Quality Gate Pattern

Wiederverwendbarer Workflow mit Standard-Prüfungen:

1. **GitLeaks:** Secret-Scanning
2. **PSScriptAnalyzer:** PowerShell Code-Qualität
3. **Pester:** Automatisierte Tests
4. **Evaluation:** Custom Gate-Logik

Trigger: `workflow_call` + `pull_request` für Wiederverwendung.

### Release Pipeline Struktur

```
Quality Gate (prüfe Qualität)
    ↓
Release (erstelle Tag & Artefakte)
    ↓
Badge-Update (aktualisiere Dokumentation)
```

3 abhängige Jobs, klare Verantwortlichkeit.

### GitHub App Token statt PATs
- Scoped Permissions per Repository
- Audit Trail in GitHub Logs
- Automatischer Ruleset Bypass
- Sichere Alternative zu Personal Access Tokens

### CI-Scripts Auslagerung
- Scripts in `.github/scripts/` (nicht inline YAML)
- Bessere Wartbarkeit
- Einfacheres Testen lokal
- Versionskontrolle

### Konfigurierbare Runner-Versionen
- `vars.UBUNTU_VERSION` für Runner-Flexibilität
- Ermöglicht schnelle Updates ohne Workflow-Änderungen

### Auto-Onboarding
- Azure Function + Webhook
- Neue Repos via `repository_dispatch` automatisch registrieren
- Self-Service für Entwickler

## PowerShell-Modul-Design

### Manifest-Struktur (.psd1)
```powershell
@{
    RootModule = 'ModuleName.psm1'
    ModuleVersion = '1.0.0'
    RequiredModules = @('OtherModule')
    FunctionsToExport = @('Get-Something')
    PrivateFunctionsToExport = @()
}
```

### Public/Private Function Trennung
- `public/` — Exportierte Funktionen
- `private/` — Nur interne Nutzung
- `FunctionsToExport` im Manifest mit `PrivateFunctionsToExport` gegenchecken

### Dependency Management
- **RequiredModules:** In Manifest deklarieren
- **ExternalModuleDependencies:** Für PowerShell Gallery
- Versions-Constraints: `@{ModuleName='1.0.0'}`

### Module Publishing
- **GitHub Packages:** Für interne Verteilung
- **PowerShell Gallery:** Für öffentliche Module
- **Authentifizierung:** Token-basiert in CI

## Release-Strategie

### Branching-Modelle

**Trunk-based Development:**
- Alle Features auf `main`
- Schnelle Integration
- Hohe Test-Anforderungen

**GitFlow:**
- `develop` + `main`
- Release-Branches isoliert
- Längere Release-Zyklen

**GitHub Flow:**
- `main` + Feature-Branches
- Release via Tags
- Lean und einfach

### Versioning (SemVer mit Conventional Commits)

```
<major>.<minor>.<patch>[-prerelease][+build]

feat() → MINOR (1.2.0)
fix() → PATCH (1.2.1)
feat()! → MAJOR (2.0.0)
```

### Changelog-Generierung

Aus Conventional Commits:
1. **feat** → Hinzugefügt
2. **fix** → Behoben
3. **perf** → Verbessert
4. **refactor** → Geändert
5. **Breaking Changes** → Oben

Issue-Referenzen verlinken.

### Approval Gates & Environment Protection Rules
- Production Deployments erfordern Approval
- Automatisierte Rollback-Trigger
- Audit Trail aller Deployments

### Rollback-Strategien
- **Blue-Green Deployments:** Zwei identische Umgebungen
- **Canary Releases:** Schrittweise Rollout
- **Feature Flags:** Schnelle Deaktivierung
- **Git Revert:** Für Code-Rollback

## GitHub Packages / NuGet Feed

### Package-Struktur
```
Organization/PackageName/Version
```

Naming: lowercase, dashes für Trennung.

### Versioning
- **Pre-release:** `1.0.0-alpha.1`, `1.0.0-beta.1`
- **Stable:** `1.0.0`
- **Smart Tags:** Aktualisiere `latest` nach Stable-Release

### CI-basiertes Publishing
- Nur Stable-Releases publizieren
- Alle Branches können zu GitHub Packages
- Nur bestimmter Branch zu PowerShell Gallery

### Feed-Authentifizierung
```yaml
- run: dotnet nuget add source https://nuget.pkg.github.com/${{ github.repository_owner }}/index.json -n "github" -u ${{ github.actor }} -p ${{ secrets.GITHUB_TOKEN }}
```

## Related Skills

- github-actions-patterns
- releaseflow-domain
- powershell-module-design

## Workflow

1. **Ist-Zustand erfassen:** Vorhandene Workflows, Scripts, Release-Prozesse
2. **Anforderung verstehen:** Was soll automatisiert werden? Welche Gates?
3. **Architektur entwerfen:** Pipeline-Design mit konkreten Jobs
4. **Schätzung:** Aufwand für Implementierung und Wartung
5. **Delegation:** Handoff an PowerShell Engineer oder Azure Specialist

## Regeln

- Empfehle **wiederverwendbare** Lösungen (Reusable Workflows, Composite Actions)
- Berücksichtige **Cost of Runners** (Self-hosted vs. GitHub-hosted)
- **Security First:** Secrets nie in Logs, OIDC statt statischer Keys
- Keine Implementierung — nur Architektur-Entscheidungen

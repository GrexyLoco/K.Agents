---
name: automation-architecture
description: CI/CD Pipeline-Architektur, PowerShell Module, GitHub Packages, Release-Strategien, ReleaseFlow
---

# 1. Automation-Architecture Skill

## 1.1 Übersicht

Dieses Skill behandelt CI/CD-Pipeline-Design, PowerShell Module-Struktur, GitHub Packages Publishing und Release-Strategien mit K.Actions.ReleaseFlow.

## 1.2 GitHub Actions Workflow-Architektur

### 1.2.1 Reusable Workflows vs. Composite Actions

| Aspekt | Reusable Workflows | Composite Actions |
|--------|-------------------|-------------------|
| **Umfang** | Komplette Workflows | Einzelne Schritte |
| **Trigger** | `workflow_call` + Standard | Als `run` Step |
| **Matrix-Support** | Ja | Nein |
| **Komplexität** | Höher | Niedriger |
| **Wiederverwendung** | Job-Level | Step-Level |

**Empfehlung:** Reusable Workflows für Multi-Job-Pipelines, Composite Actions für Utility-Schritte.

### 1.2.2 Matrix-Builds für Multi-Plattform

```yaml
strategy:
  matrix:
    os: [ubuntu-latest, windows-latest, macos-latest]
    dotnet-version: [8.0, 9.0, 10.0]
  fail-fast: false
```

Nutze für .NET auf Windows/Linux/macOS, um Plattform-spezifische Bugs früh zu finden.

### 1.2.3 Caching-Strategien
- **NuGet:** `~/.nuget/packages` mit `nuget-version`
- **dotnet restore:** `global.json` als Cache-Key
- **Build-Artefakte:** Nur zwischen abhängigen Jobs
- **Docker Layers:** Für Container-Builds

### 1.2.4 Workflow-Trigger-Design
- **push:** Nur auf Main/Release-Branches
- **pull_request:** Auf alle Branches, read-only Secrets
- **release:** Nach Release-Erstellung
- **schedule:** Nächtliche Security-Scans
- **workflow_dispatch:** Manuelle Trigger mit Parametern

### 1.2.5 Secret Management
- **GitHub App Token:** Scoped Permissions, Audit Trail, Ruleset Bypass
- **OIDC-basierte Authentifizierung:** Für Cloud-Services
- **Secrets minimal:** Nur wo nötig, masken in Logs
- **PATs vermeiden:** Legacy, unsicher für Automation

### 1.2.6 Workflow Concurrency

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

Stoppe alte Runs wenn neue auf gleicher Branch starten.

## 1.3 K.Actions.ReleaseFlow Architektur

### 1.3.1 Quality Gate Pattern

Wiederverwendbarer Workflow mit Standard-Prüfungen:

1. **GitLeaks:** Secret-Scanning
2. **PSScriptAnalyzer:** PowerShell Code-Qualität
3. **Pester:** Automatisierte Tests
4. **Evaluation:** Custom Gate-Logik

Trigger: `workflow_call` + `pull_request` für Wiederverwendung.

### 1.3.2 Release Pipeline Struktur

```
Quality Gate (prüfe Qualität)
    ↓
Release (erstelle Tag & Artefakte)
    ↓
Badge-Update (aktualisiere Dokumentation)
```

3 abhängige Jobs, klare Verantwortlichkeit.

### 1.3.3 GitHub App Token statt PATs
- Scoped Permissions per Repository
- Audit Trail in GitHub Logs
- Automatischer Ruleset Bypass
- Sichere Alternative zu Personal Access Tokens

### 1.3.4 CI-Scripts Auslagerung
- Scripts in `.github/scripts/` (nicht inline YAML)
- Bessere Wartbarkeit
- Einfacheres Testen lokal
- Versionskontrolle

### 1.3.5 Konfigurierbare Runner-Versionen
- `vars.UBUNTU_VERSION` für Runner-Flexibilität
- Ermöglicht schnelle Updates ohne Workflow-Änderungen

### 1.3.6 Auto-Onboarding
- Azure Function + Webhook
- Neue Repos via `repository_dispatch` automatisch registrieren
- Self-Service für Entwickler

## 1.4 PowerShell-Modul-Design

### 1.4.1 Manifest-Struktur (.psd1)
```powershell
@{
    RootModule = 'ModuleName.psm1'
    ModuleVersion = '1.0.0'
    RequiredModules = @('OtherModule')
    FunctionsToExport = @('Get-Something')
    PrivateFunctionsToExport = @()
}
```

### 1.4.2 Public/Private Function Trennung
- `public/` — Exportierte Funktionen
- `private/` — Nur interne Nutzung
- `FunctionsToExport` im Manifest mit `PrivateFunctionsToExport` gegenchecken

### 1.4.3 Dependency Management
- **RequiredModules:** In Manifest deklarieren
- **ExternalModuleDependencies:** Für PowerShell Gallery
- Versions-Constraints: `@{ModuleName='1.0.0'}`

### 1.4.4 Module Publishing
- **GitHub Packages:** Für interne Verteilung
- **PowerShell Gallery:** Für öffentliche Module
- **Authentifizierung:** Token-basiert in CI

## 1.5 Release-Strategie

### 1.5.1 Branching-Modelle

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

### 1.5.2 Versioning (SemVer mit Conventional Commits)

```
<major>.<minor>.<patch>[-prerelease][+build]

feat() → MINOR (1.2.0)
fix() → PATCH (1.2.1)
feat()! → MAJOR (2.0.0)
```

### 1.5.3 Changelog-Generierung

Aus Conventional Commits:
1. **feat** → Hinzugefügt
2. **fix** → Behoben
3. **perf** → Verbessert
4. **refactor** → Geändert
5. **Breaking Changes** → Oben

Issue-Referenzen verlinken.

### 1.5.4 Approval Gates & Environment Protection Rules
- Production Deployments erfordern Approval
- Automatisierte Rollback-Trigger
- Audit Trail aller Deployments

### 1.5.5 Rollback-Strategien
- **Blue-Green Deployments:** Zwei identische Umgebungen
- **Canary Releases:** Schrittweise Rollout
- **Feature Flags:** Schnelle Deaktivierung
- **Git Revert:** Für Code-Rollback

## 1.6 GitHub Packages / NuGet Feed

### 1.6.1 Package-Struktur
```
Organization/PackageName/Version
```

Naming: lowercase, dashes für Trennung.

### 1.6.2 Versioning
- **Pre-release:** `1.0.0-alpha.1`, `1.0.0-beta.1`
- **Stable:** `1.0.0`
- **Smart Tags:** Aktualisiere `latest` nach Stable-Release

### 1.6.3 CI-basiertes Publishing
- Nur Stable-Releases publizieren
- Alle Branches können zu GitHub Packages
- Nur bestimmter Branch zu PowerShell Gallery

### 1.6.4 Feed-Authentifizierung
```yaml
- run: dotnet nuget add source https://nuget.pkg.github.com/${{ github.repository_owner }}/index.json -n "github" -u ${{ github.actor }} -p ${{ secrets.GITHUB_TOKEN }}
```

## 1.7 Related Skills

- github-actions-patterns
- releaseflow-domain
- powershell-module-design

## 1.8 Workflow

1. **Ist-Zustand erfassen:** Vorhandene Workflows, Scripts, Release-Prozesse
2. **Anforderung verstehen:** Was soll automatisiert werden? Welche Gates?
3. **Architektur entwerfen:** Pipeline-Design mit konkreten Jobs
4. **Schätzung:** Aufwand für Implementierung und Wartung
5. **Delegation:** Handoff an PowerShell Engineer oder Azure Specialist

## 1.9 Regeln

- Empfehle **wiederverwendbare** Lösungen (Reusable Workflows, Composite Actions)
- Berücksichtige **Cost of Runners** (Self-hosted vs. GitHub-hosted)
- **Security First:** Secrets nie in Logs, OIDC statt statischer Keys
- Keine Implementierung — nur Architektur-Entscheidungen

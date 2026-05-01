---
name: git-forensics
description: Git-Historia-Analyse — blame, bisect, pickaxe, Conventional Commits Validierung, Changelog-Generierung, Change Tracking
---

# Git-Forensics Skill

## Übersicht

Dieses Skill behandelt systematische Git-Analyse um herauszufinden, wann Änderungen eingeführt wurden, welche Issues sie betreffen und wie sie zusammenhängen. Es umfasst Conventional Commits Enforcement und automatische Changelog-Generierung.

## ReleaseFlow-Branching-Kontext

K.Actions.ReleaseFlow nutzt ein standardisiertes Branching-Modell:

### Branch-Struktur
```
feature/* → dev/vX.Y.Z (Alpha-Phase)
fix/*     → dev/vX.Y.Z oder release/vX.Y.Z (Alpha/Beta)
dev/vX.Y.Z → release/vX.Y.Z (Feature-Freeze Promotion)
release/vX.Y.Z → main (Stable-Release)
```

### Tag-Typen
- **Alpha:** `vX.Y.Z-alphaN` (instabil, Development)
- **Beta:** `vX.Y.Z-betaN` (pre-release Testing)
- **Freeze:** `vX.Y.Z-freeze` (Feature-Freeze Markierung)
- **Stable:** `vX.Y.Z` (Release-Tag)
- **Smart Tags:** `vX`, `vX.Y`, `latest` (automatisch verschoben bei Stable-Release)

### Release-Train Analyse
```bash
# Commits im Release-Train finden
git log --all --grep="dev/v" --oneline

# Zwischen Release-Versions
git log vX.Y.Z-freeze..release/vX.Y.Z
```

Freeze-Tags markieren den Feature-Freeze-Punkt. Backflow PRs (`main` → offene `dev/*`) nach Stable-Release prüfen.

## Analysemethoden

### „Wann kam diese Änderung rein?"

**Pickaxe (Suche nach Code-Änderung):**
```bash
git log --all -S "searchtext" --oneline --date=short --format="%h %ad %s"
```

Findet alle Commits, die die Zeile hinzugefügt oder entfernt haben.

**Log mit Commit-Messages:**
```bash
git log --all --grep="suchtext" --oneline
```

Sucht in Commit-Message nach Keyword.

**Blame für spezifische Zeile:**
```bash
git blame -L 42,42 path/to/file.cs
```

Zeigt wer zuletzt diese Zeile geändert hat.

**Follow mit Renames:**
```bash
git log --follow -p path/to/file.cs
```

Trackt Datei auch wenn sie umbenannt wurde.

### „Seit wann existiert dieser Bug?"

**Automatischer Bisect:**
```bash
git bisect start
git bisect bad HEAD
git bisect good v1.0.0
git bisect run dotnet test --filter "TestName"
```

Bisect findet automatisch den ersten Bad-Commit durch Binärsuche.

**Manueller Bisect:**
```bash
git bisect start
git bisect bad
git bisect good abc123
# Test und prüfen
git bisect good  # oder git bisect bad
# ... bis Commit gefunden
```

### „Welches Issue/PR hat das eingeführt?"

1. Commit via `git blame` oder `git log -S` finden
2. Commit-Message auf Issue-Referenzen prüfen (`#42`, `fixes #42`)
3. GitHub MCP: PR suchen der diesen Commit enthält
4. Issue aus PR-Beschreibung oder Linked Issues extrahieren

### „Was hat sich zwischen Releases geändert?"

```bash
# Commits zwischen Tags
git log --oneline v1.0.0..v1.1.0

# Nur Dateien die geändert wurden
git diff --stat v1.0.0..v1.1.0

# Änderungen gruppiert nach Autor
git shortlog v1.0.0..v1.1.0

# Nur feat und fix Commits
git log --oneline v1.0.0..v1.1.0 --grep="^feat"
git log --oneline v1.0.0..v1.1.0 --grep="^fix"
```

### „Wer hat zuletzt an dieser Datei gearbeitet?"

```bash
# Letzte 10 Änderungen an einer Datei
git log --follow --oneline -10 path/to/file.cs

# Autoren-Statistik
git shortlog -sn --all -- path/to/file.cs
```

## Conventional Commits

### Format (Pflicht)
```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

Beispiel:
```
feat(api): Benutzer-Endpoint mit Pagination implementiert

Erlaubt die Paginierung von Benutzerlisten
mit limit und offset Parametern.

Fixes #42
```

### Types und SemVer

| Type | Beschreibung | SemVer | Changelog |
|------|-------------|--------|-----------|
| `feat` | Neues Feature | MINOR | Hinzugefügt |
| `fix` | Bugfix | PATCH | Behoben |
| `docs` | Nur Dokumentation | — | (skip) |
| `style` | Formatierung, kein Code-Change | — | (skip) |
| `refactor` | Weder Feature noch Fix | — | Geändert |
| `perf` | Performance-Verbesserung | PATCH | Verbessert |
| `test` | Tests hinzufügen/ändern | — | (skip) |
| `chore` | Build, Dependencies | — | (skip) |
| `ci` | CI/CD Konfiguration | — | (skip) |

### Scopes (projektspezifisch)

- **Modules:** `blazor`, `maui`, `api`, `efcore`, `aspire`
- **Automation:** `ci`, `cd`, `actions`, `github`
- **Scripting:** `ps`, `pwsh` (PowerShell)
- **Infrastructure:** `infra`, `azure`, `docker`
- **Documentation:** `docs`

### Breaking Changes

```
feat(api)!: Ändere Rückgabeformat auf RFC 7807

BREAKING CHANGE: Der Endpoint `/api/users` gibt jetzt
ProblemDetails zurück statt ErrorResponse.

Migration: Passe Client-Code an das neue Format an.
```

Nutze `!` vor dem Doppelpunkt oder `BREAKING CHANGE:` Footer für MAJOR-Version.

### Commit-Message-Qualität Validierung

**Verboten:**
- „fix", „update", „changes", „stuff", „wip" als alleinige Message
- Commits ohne Type-Prefix
- Scope fehlt bei Monorepo-Änderungen
- Breaking Changes ohne `!` oder `BREAKING CHANGE:` Footer

**Gut:**
```
feat(blazor): Benutzer-Tabelle mit Sortierung implementiert (#42)
fix(api): Null-Reference bei leerem Query-Parameter behoben (#43)
chore(ci): Build-Cache für NuGet-Pakete aktiviert
```

## Changelog-Generierung

Sammle Commits seit dem letzten Release-Tag und kategorisiere nach Conventional Commits:

```markdown
# Changelog

## [1.2.0] - 2026-03-21

### Breaking Changes
- `/api/v1/legacy` Endpoint entfernt (#40)

### Hinzugefügt
- Benutzer-Export als CSV (#42)
- Health Check Endpoint für Monitoring (#45)

### Geändert
- API-Antwortformat auf RFC 7807 Problem Details umgestellt (#43)

### Behoben
- Fehler bei der Datumsformatierung in der Benutzeransicht (#44)

### Entfernt
- Veralteter `/api/v1/legacy` Endpoint (#40)
```

**Kategorisierung:**
1. Breaking Changes (immer oben)
2. `feat` → Hinzugefügt
3. `fix` → Behoben
4. `perf` → Verbessert
5. `refactor` → Geändert
6. Issue-Referenzen verlinken

## Workflow

1. **Frage verstehen:** Wann? Wer? Warum? Welches Issue?
2. **Passende Methode:** blame, log, bisect, diff wählen
3. **Analyse:** Git-Befehle ausführen
4. **Ergebnis:** Commit, Autor, Datum, Issue-Referenz dokumentieren
5. **Bei Bedarf:** Handoff an Developer für Fix

## Related Skills

- conventional-commits
- releaseflow-domain
- release-management

## Regeln

- Ergebnisse immer mit **konkreten Commits** belegen (SHA, Datum, Autor)
- Keine Vermutungen — nur Git-Historie zeigen
- Bisect: Reproduzierbaren Test-Befehl dokumentieren
- Conventional Commits durchsetzen in Code Reviews
- Keine Code-Fixes selbst implementieren

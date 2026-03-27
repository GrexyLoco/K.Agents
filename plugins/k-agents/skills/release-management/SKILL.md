---
name: release-management
description: Release processes, versioning, and changelog generation. Use this skill for release planning and execution.

# Release Management

## Versioning (SemVer)
```
MAJOR.MINOR.PATCH
  │      │     └── Bugfixes, keine API-Änderungen
  │      └──────── Neue Features, abwärtskompatibel
  └─────────────── Breaking Changes
```

## Pre-Release Versionen
- Alpha: `1.2.0-alpha.1` (interne Tests)
- Beta: `1.2.0-beta.1` (externe Tests)
- RC: `1.2.0-rc.1` (Release Candidate)

## Release-Workflow
1. Feature-Branch → `main` via PR (Squash Merge)
2. Conventional Commits prüfen
3. Version bumpen (basierend auf Commits seit letztem Tag)
4. Changelog generieren
5. Git Tag erstellen (`v1.2.0`)
6. GitHub Release erstellen
7. NuGet Package publishen (wenn Library)

## GitHub Release erstellen
```bash
gh release create v1.2.0 \
  --title "v1.2.0" \
  --notes-file CHANGELOG.md \
  --target main
```

## Changelog-Format (Keep a Changelog)
```markdown
## [1.2.0] - 2026-03-21
### Hinzugefügt
- Feature X (#42)
### Behoben
- Bug Y (#43)
### Breaking Changes
- API Z geändert (#44) — Migration: ...
```

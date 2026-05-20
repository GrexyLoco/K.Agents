---
name: release-management
description: "Release execution — SemVer versioning (MAJOR.MINOR.PATCH), pre-release labels (alpha, beta, rc), changelog generation (Keep a Changelog format), git tagging, GitHub Release creation with gh CLI. USE FOR: executing releases, generating changelogs, creating version tags and GitHub Releases. DO NOT USE FOR: ReleaseFlow branching or phase rules (use releaseflow-domain) or commit message format (use conventional-commits)."
---

# 1. Release Management

## 1.1 Versioning (SemVer)
```
MAJOR.MINOR.PATCH
  │      │     └── Bugfixes, keine API-Änderungen
  │      └──────── Neue Features, abwärtskompatibel
  └─────────────── Breaking Changes
```

## 1.2 Pre-Release Versionen
- Alpha: `1.2.0-alpha.1` (interne Tests)
- Beta: `1.2.0-beta.1` (externe Tests)
- RC: `1.2.0-rc.1` (Release Candidate)

## 1.3 Release-Workflow
1. Feature-Branch → `main` via PR (Squash Merge)
2. Conventional Commits prüfen
3. Version bumpen (basierend auf Commits seit letztem Tag)
4. Changelog generieren
5. Git Tag erstellen (`v1.2.0`)
6. GitHub Release erstellen
7. NuGet Package publishen (wenn Library)

## 1.4 GitHub Release erstellen
```bash
gh release create v1.2.0 \
  --title "v1.2.0" \
  --notes-file CHANGELOG.md \
  --target main
```

## 1.5 Changelog-Format (Keep a Changelog)
```markdown
## [1.2.0] - 2026-03-21
### Hinzugefügt
- Feature X (#42)
### Behoben
- Bug Y (#43)
### Breaking Changes
- API Z geändert (#44) — Migration: ...
```

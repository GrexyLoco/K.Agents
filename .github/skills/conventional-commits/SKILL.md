---
name: conventional-commits
description: Conventional Commits — type/scope/description format (feat, fix, docs, refactor, perf, test, chore, ci), breaking changes, scopes (.NET, CI/CD, PowerShell), SemVer mapping. USE FOR: writing commit messages, validating commit format, understanding version-bump rules. DO NOT USE FOR: release process or branching (use releaseflow-domain) or changelog file creation (use release-management).
---

# Conventional Commits

## Format
```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

## Types
| Type | SemVer | Beschreibung |
|------|--------|-------------|
| `feat` | MINOR | Neues Feature |
| `fix` | PATCH | Bugfix |
| `docs` | — | Dokumentation |
| `style` | — | Formatierung |
| `refactor` | — | Code-Umbau |
| `perf` | PATCH | Performance |
| `test` | — | Tests |
| `chore` | — | Build/CI/Deps |
| `ci` | — | CI-Konfiguration |

## Scopes
- `.NET:` `blazor`, `maui`, `api`, `efcore`, `aspire`
- `CI/CD:` `ci`, `cd`, `actions`
- `PowerShell:` `ps`, `pwsh`
- `Infra:` `infra`, `azure`

## Breaking Changes
```
feat(api)!: Ändere Rückgabeformat

BREAKING CHANGE: Beschreibung und Migrationspfad.
```

## Verboten
- Generische Messages: „fix", „update", „changes", „stuff", „wip"
- Fehlender Type-Prefix
- Fehlender Scope bei Monorepo
- Body ohne Leerzeile nach Subject

## Beispiele
- `feat(blazor): Benutzer-Tabelle mit Sortierung (#42)`
- `fix(api): Null-Reference bei leerem Query-Parameter (#43)`
- `chore(ci): NuGet-Cache in Build-Workflow aktiviert`
- `docs(readme): Installationsanleitung aktualisiert`

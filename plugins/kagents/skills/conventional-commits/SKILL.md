---
name: conventional-commits
description: "Conventional Commits — type/scope/description format (feat, fix, docs, refactor, perf, test, chore, ci), breaking changes, scopes (.NET, CI/CD, PowerShell), SemVer mapping. USE FOR: writing commit messages, validating commit format, understanding version-bump rules. DO NOT USE FOR: release process or branching (use releaseflow-domain) or changelog file creation (use release-management)."
---

# 1. Conventional Commits

## 1.1 Format
```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

## 1.2 Types
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

## 1.3 Scopes
- `.NET:` `blazor`, `maui`, `api`, `efcore`, `aspire`
- `CI/CD:` `ci`, `cd`, `actions`
- `PowerShell:` `ps`, `pwsh`
- `Infra:` `infra`, `azure`

## 1.4 Breaking Changes
```
feat(api)!: Ändere Rückgabeformat

BREAKING CHANGE: Beschreibung und Migrationspfad.
```

## 1.5 Verboten
- Generische Messages: „fix", „update", „changes", „stuff", „wip"
- Fehlender Type-Prefix
- Fehlender Scope bei Monorepo
- Body ohne Leerzeile nach Subject

## 1.6 Beispiele
- `feat(blazor): Benutzer-Tabelle mit Sortierung (#42)`
- `fix(api): Null-Reference bei leerem Query-Parameter (#43)`
- `chore(ci): NuGet-Cache in Build-Workflow aktiviert`
- `docs(readme): Installationsanleitung aktualisiert`

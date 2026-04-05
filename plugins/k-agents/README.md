# K.Agents

**14 AI-Agents (13 spezialisierte + 1 Orchestrator) und 27 Skills** für .NET 10, C# 14, Blazor, MAUI, PowerShell Core, GitHub Actions und Azure.

## Überblick

Kuratierte Sammlung von Custom Agents und Skills für VS Code Copilot, Visual Studio 2026 und Claude Code. Jeder Agent hat eine klar definierte Rolle mit Handoff-Buttons zur nahtlosen Zusammenarbeit.

## Agents

### Einstieg

| Agent | Beschreibung | Model |
|-------|-------------|-------|
| Orchestrator | Automatisches Routing — analysiert Aufgabe und delegiert sofort | Haiku |

### Strategie & Planung

| Agent | Beschreibung | Model |
|-------|-------------|-------|
| Planning Agent | Feature-Planung → GitHub Issues/Milestones | Opus |
| App Architect | .NET/Blazor/MAUI Architektur, Modular Monolith | Opus |
| Automation Architect | CI/CD, Workflows, Release-Strategie | Opus |

### Implementierung

| Agent | Beschreibung | Model |
|-------|-------------|-------|
| .NET Developer | C# 14, Blazor, MAUI, APIs | Sonnet |
| PowerShell Engineer | Cross-Platform PS Core, GitHub Actions | Sonnet |
| Azure Specialist | Aspire, Monitoring + EU-Alternativen | Sonnet |
| Database Engineer | EF Core, Migrations, Performance | Sonnet |

### Qualitätssicherung

| Agent | Beschreibung | Model |
|-------|-------------|-------|
| TUnit Tester | .NET Tests mit TUnit | Sonnet |
| Pester Tester | PowerShell Tests mit Pester 5.6 | Sonnet |
| Security Auditor | OWASP, Dependency Scanning | Sonnet |
| Code Reviewer | Patterns, Performance, Architektur | Opus |

### Querschnitt

| Agent | Beschreibung | Model |
|-------|-------------|-------|
| Documentation | README, Changelog, API-Docs | Sonnet |
| Git Forensics | Blame, Bisect, Conventional Commits | Sonnet |

## Skills (27)

| Kategorie | Skills |
|-----------|--------|
| C# / .NET | `csharp-patterns`, `csharp-concurrency-patterns`, `minimal-api-patterns` |
| Blazor | `blazor-patterns`, `playwright-blazor-testing` |
| MAUI | `maui-patterns`, `maui-blazor-hybrid`, `maui-performance`, `maui-accessibility`, `maui-hot-reload` |
| Aspire | `aspire-architecture`, `aspire-integration-testing` |
| EF Core | `efcore-patterns`, `database-performance` |
| Testing | `tunit-patterns`, `pester-patterns` |
| CI/CD | `github-actions-patterns`, `github-actions-debugging` |
| PowerShell | `powershell-module-design` |
| Azure | `azure-monitoring` |
| Security | `owasp-dotnet` |
| Release | `release-management`, `conventional-commits`, `releaseflow-domain`, `releaseflow-coding-patterns` |
| Build | `dotnet-build-diagnosis`, `dotnet-aot-compat` |

## Besonderheiten

- **TUnit** als .NET-Testframework (nicht xUnit/NUnit)
- **Pester 5.6.x** für PowerShell-Tests
- **ReleaseFlow-Integration** (K.Actions.ReleaseFlow Domänenwissen)
- **EU-Souveränitäts-Pflicht** beim Azure Specialist
- **Write-Host überall verboten** (auch CI-Scripts)
- **Deutsch** als Arbeitssprache für Doku, Issues, Commits

## Lizenz

MIT — Siehe [LICENSE](../../LICENSE) für Details.

# K.Agents — Spezialisierte AI-Agents für .NET, PowerShell & Azure

[![Release](https://img.shields.io/github/v/release/GrexyLoco/K.Agents?include_prereleases&label=version)](https://github.com/GrexyLoco/K.Agents/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Agents](https://img.shields.io/badge/Agents-13-blue)](.github/agents/)
[![Skills](https://img.shields.io/badge/Skills-27-green)](.github/skills/)

Kuratierte Sammlung von **13 Custom Agents** und **27 Skills** für VS Code Copilot und Claude Code.
Optimiert für .NET 10, C# 14, Blazor, MAUI, PowerShell Core, GitHub Actions und Azure.

## Besonderheiten

- **TUnit** als .NET-Testframework (nicht xUnit/NUnit)
- **Pester 5.6.x** für PowerShell-Tests
- **ReleaseFlow-Integration** (K.Actions.ReleaseFlow Domänenwissen)
- **EU-Souveränitäts-Pflicht** beim Azure Specialist (immer Kosten dev/prod + Alternative)
- **Write-Host überall verboten** (auch CI-Scripts)
- **Deutsch** als Arbeitssprache für Doku, Issues, Commits

## Installation

> **[→ Ausführliche Installationsanleitung](INSTALLATION.md)** — Alle Methoden, Multi-Repo-Setup, Token-FAQ und offizielle Quellen.

**Schnellstart (Plugin — einmal installieren, in allen Repos verfügbar):**
```bash
/plugin marketplace add GrexyLoco/K.Agents
/plugin install k-agents@k-agents
```

**Schnellstart (VS Code Settings):**
```json
{
  "chat.plugins.enabled": true,
  "chat.plugins.marketplaces": ["GrexyLoco/K.Agents"]
}
```

## Agents

### Strategie & Planung
| Agent | Beschreibung | Model |
|-------|-------------|-------|
| [Planning Agent](plugins/k-agents/agents/planning.agent.md) | Feature-Planung → GitHub Issues/Milestones | Opus |
| [App Architect](plugins/k-agents/agents/app-architect.agent.md) | .NET/Blazor/MAUI Architektur, Modular Monolith | Opus |
| [Automation Architect](plugins/k-agents/agents/automation-architect.agent.md) | CI/CD, Workflows, Release-Strategie | Opus |

### Implementierung
| Agent | Beschreibung | Model |
|-------|-------------|-------|
| [.NET Developer](plugins/k-agents/agents/dotnet-developer.agent.md) | C# 14, Blazor, MAUI, APIs | Sonnet |
| [PowerShell Engineer](plugins/k-agents/agents/powershell-engineer.agent.md) | Cross-Platform PS Core, GitHub Actions | Sonnet |
| [Azure Specialist](plugins/k-agents/agents/azure-specialist.agent.md) | Aspire, Monitoring + EU-Alternativen | Sonnet |
| [Database Engineer](plugins/k-agents/agents/database-engineer.agent.md) | EF Core, Migrations, Performance | Sonnet |

### Qualitätssicherung
| Agent | Beschreibung | Model |
|-------|-------------|-------|
| [TUnit Tester](plugins/k-agents/agents/tunit-tester.agent.md) | .NET Tests mit TUnit | Sonnet |
| [Pester Tester](plugins/k-agents/agents/pester-tester.agent.md) | PowerShell Tests mit Pester 5.6 | Sonnet |
| [Security Auditor](plugins/k-agents/agents/security-auditor.agent.md) | OWASP, Dependency Scanning | Sonnet |
| [Code Reviewer](plugins/k-agents/agents/code-reviewer.agent.md) | Patterns, Performance, Architektur | Opus |

### Querschnitt
| Agent | Beschreibung | Model |
|-------|-------------|-------|
| [Documentation](plugins/k-agents/agents/documentation.agent.md) | README, Changelog, API-Docs | Sonnet |
| [Git Forensics](plugins/k-agents/agents/git-forensics.agent.md) | Blame, Bisect, Conventional Commits | Sonnet |

## Skills

### Eigene Skills (17)
| Kategorie | Skills |
|-----------|--------|
| C# / .NET | `csharp-patterns`, `minimal-api-patterns` |
| Blazor | `blazor-patterns` |
| MAUI | `maui-patterns` |
| Aspire | `aspire-architecture` |
| EF Core | `efcore-patterns` |
| Testing | `tunit-patterns`, `pester-patterns` |
| CI/CD | `github-actions-patterns`, `github-actions-debugging` |
| PowerShell | `powershell-module-design` |
| Azure | `azure-monitoring` |
| Security | `owasp-dotnet` |
| Release | `release-management`, `conventional-commits` |
| ReleaseFlow | `releaseflow-domain`, `releaseflow-coding-patterns` |

### OSS-adaptierte Skills (10)
| Skill | Quelle | Lizenz |
|-------|--------|--------|
| `dotnet-build-diagnosis` | [dotnet/skills](https://github.com/dotnet/skills) | MIT |
| `dotnet-aot-compat` | [dotnet/skills](https://github.com/dotnet/skills) | MIT |
| `maui-blazor-hybrid` | [davidortinau/maui-skills](https://github.com/davidortinau/maui-skills) | MIT |
| `maui-performance` | [davidortinau/maui-skills](https://github.com/davidortinau/maui-skills) | MIT |
| `maui-accessibility` | [davidortinau/maui-skills](https://github.com/davidortinau/maui-skills) | MIT |
| `maui-hot-reload` | [davidortinau/maui-skills](https://github.com/davidortinau/maui-skills) | MIT |
| `playwright-blazor-testing` | [Aaronontheweb/dotnet-skills](https://github.com/Aaronontheweb/dotnet-skills) | MIT |
| `aspire-integration-testing` | [Aaronontheweb/dotnet-skills](https://github.com/Aaronontheweb/dotnet-skills) | MIT |
| `database-performance` | [Aaronontheweb/dotnet-skills](https://github.com/Aaronontheweb/dotnet-skills) | MIT |
| `csharp-concurrency-patterns` | [Aaronontheweb/dotnet-skills](https://github.com/Aaronontheweb/dotnet-skills) | MIT |

## Kompatibilität

| Umgebung | Status | Hinweis |
|----------|--------|---------|
| VS Code + GitHub Copilot | ✅ Primär | `.agent.md` + `.github/skills/` |
| Visual Studio 2026 | ✅ | `.github/agents/` wird erkannt |
| Claude Code | ✅ | `.claude/agents/` Symlink oder Plugin |
| Copilot CLI | ✅ | Plugin Marketplace |
| GitHub Copilot Coding Agent | ✅ | Liest `.github/agents/` |

## Mitwirken

Siehe [CONTRIBUTING.md](CONTRIBUTING.md) für Richtlinien.

## Danksagung

OSS-Skills adaptiert von:
- [dotnet/skills](https://github.com/dotnet/skills) — Microsoft .NET Team
- [davidortinau/maui-skills](https://github.com/davidortinau/maui-skills) — David Ortinau (Microsoft PM)
- [Aaronontheweb/dotnet-skills](https://github.com/Aaronontheweb/dotnet-skills) — Aaron Stannard

## Lizenz

[MIT](LICENSE) © GrexyLoco


trigger
<!-- ci -->

<!-- release-test 20:04:32 -->

<!-- nuget-v3-test 20:08:49 -->

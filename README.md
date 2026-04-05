# K.Agents — Spezialisierte AI-Agents fuer .NET, PowerShell & Azure

[![Release](https://img.shields.io/github/v/release/GrexyLoco/K.Agents?include_prereleases&label=version)](https://github.com/GrexyLoco/K.Agents/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Agents](https://img.shields.io/badge/Agents-14-blue)](.github/agents/)
[![Skills](https://img.shields.io/badge/Skills-27-green)](.github/skills/)

Kuratierte Sammlung von **14 Custom Agents** (13 spezialisierte + 1 Orchestrator), **27 Skills** und **2 MCP-Server** für VS Code Copilot, Visual Studio 2026 und Claude Code.
Optimiert für .NET 10, C# 14, Blazor, MAUI, PowerShell Core, GitHub Actions und Azure.

## Inhaltsverzeichnis

- [Besonderheiten](#besonderheiten)
- [Installation](#installation)
- [Agents](#agents)
- [Skills](#skills)
- [MCP-Server](#mcp-server)
- [Kompatibilität](#kompatibilität)
- [Agent-Workflow & Handoff-Flows](#agent-workflow--handoff-flows)
- [Mitwirken](#mitwirken)
- [Danksagung](#danksagung)
- [Lizenz](#lizenz)

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
/plugin install kagents@K.Agents
```

**Schnellstart (VS Code Settings):**
```json
{
  "chat.plugins.enabled": true,
  "chat.plugins.marketplaces": ["GrexyLoco/K.Agents"]
}
```

## Agents

### Einstieg (Orchestrator)
| Agent | Beschreibung | Model |
|-------|-------------|-------|
| [Orchestrator](plugins/k-agents/agents/orchestrator.agent.md) | Automatisches Routing — analysiert Aufgabe und delegiert sofort | Haiku |

**Nutzung:**
```powershell
# Claude CLI (primär)
claude --agent orchestrator "<aufgabe>"

# Copilot CLI (Fallback bei Rate Limit)
copilot --agent orchestrator "<aufgabe>"
```

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

## MCP-Server

Das Plugin liefert zwei MCP-Server mit, die automatisch im Plugin-System (VS Code, Claude Code, Copilot CLI) gestartet werden:

| Server | Typ | Funktion | Tools |
|--------|-----|----------|-------|
| **Microsoft Learn** | HTTP | Offizielle Microsoft-Dokumentation und Code-Beispiele | `microsoft_docs_search`, `microsoft_docs_fetch`, `microsoft_code_sample_search` |
| **GitHub** | HTTP | Issues, PRs, Repos, Code-Suche, Advisory Database | `list_issues`, `search_code`, `create_pull_request`, u.v.m. |

> **Voraussetzung GitHub MCP:** `gh auth login` muss einmalig ausgeführt worden sein.

> **Hinweis:** MCP-Server werden von Visual Studio 2026 nicht unterstützt. Siehe [INSTALLATION.md](INSTALLATION.md#was-das-plugin-mitliefert) für Details.

## Kompatibilität

| Umgebung | Status | Installation | Hooks & MCPs |
|----------|--------|-------------|--------------|
| VS Code + GitHub Copilot | ✅ Primär | Plugin Marketplace oder Settings | ✅ via Plugin |
| Visual Studio 2026 (ab 18.5) | ✅ | [Install-Script](scripts/Install-KAgentsVS.ps1) (User-Level Copy) | ❌ nicht unterstützt |
| Claude Code | ✅ | Plugin Marketplace | ✅ via Plugin |
| Copilot CLI | ✅ | Plugin Marketplace | ✅ via Plugin |

> **Hinweis:** Jede IDE hat ein eigenes Discovery-System. Plugins aus Copilot CLI werden weder in VS Code noch in VS 2026 erkannt. [Details → INSTALLATION.md](INSTALLATION.md#visual-studio-2026)

## Agent-Workflow & Handoff-Flows

Die Agents sind über **Handoff-Buttons** miteinander verknüpft. Nach jeder Agent-Antwort erscheinen Buttons, die zum nächsten passenden Agent weiterleiten — inklusive Kontext aus der bisherigen Konversation.

### Übersichtsgraph

```
┌─────────────────────────────────────────────────────────────────────┐
│                        STRATEGIE & PLANUNG                         │
│                                                                     │
│   ┌──────────┐        ┌───────────────┐     ┌────────────────────┐ │
│   │ Planning │──────→ │ App Architect │     │ Automation         │ │
│   │ Agent    │──────→ │               │     │ Architect          │ │
│   └──────────┘        └───────────────┘     └────────────────────┘ │
│        ▲                │  │  │  │               │  │  │  │        │
│        │ MVP planen     │  │  │  │  Tasks planen │  │  │  │        │
│        ╰────────────────╯  │  │  │  ╭────────────╯  │  │  │        │
│                            │  │  │  │               │  │  │        │
└────────────────────────────┼──┼──┼──┼───────────────┼──┼──┼────────┘
                             │  │  │  │               │  │  │
┌────────────────────────────┼──┼──┼──┼───────────────┼──┼──┼────────┐
│                        IMPLEMENTIERUNG                              │
│                            │  │  │  │               │  │  │        │
│                            ▼  │  ▼  │               ▼  │  ▼        │
│   ┌──────────────────┐       │     │     ┌──────────────────────┐  │
│   │  .NET Developer  │ ◄─────┘     │     │ PowerShell Engineer │  │
│   │                  │─────────────────→ │                      │  │
│   └──────────────────┘             │     └──────────────────────┘  │
│      │  │  │  │  │                 │         │  │  │              │
│      │  │  │  │  │                 │         │  │  │              │
│      │  │  │  │  ▼                 │         │  │  │              │
│      │  │  │  │ ┌──────────────┐   │         │  │  │              │
│      │  │  │  ╰→│ Database     │   │         │  │  │              │
│      │  │  │    │ Engineer     │───╯         │  │  │              │
│      │  │  │    └──────────────┘             │  │  │              │
│      │  │  │                                 │  │  │              │
│      │  │  ▼    ┌───────────────────┐        │  │  │              │
│      │  │  ╰───→│ Azure Specialist  │◄───────╯  │  │              │
│      │  │       └───────────────────┘           │  │              │
│      │  │                                       │  │              │
│      │  ▼       ┌───────────────────┐           │  │              │
│      │  ╰──────→│ Documentation     │◄──────────╯  │              │
│      │          └───────────────────┘              │              │
│      │                                             │              │
└──────┼─────────────────────────────────────────────┼──────────────┘
       │                                             │
┌──────┼─────────────────────────────────────────────┼──────────────┐
│      │             QUALITÄTSSICHERUNG              │              │
│      │                                             │              │
│      ▼          ┌──────────────┐                   ▼              │
│   ┌──────────┐  │ Pester       │◄──── ┌──────────────────┐       │
│   │ TUnit    │  │ Tester       │      │                  │       │
│   │ Tester   │  └──────────────┘      │  Code Reviewer   │       │
│   └──────────┘         │              │                  │       │
│      │                 │              └──────────────────┘       │
│      │                 │                │  │  │                   │
│      ▼                 ▼                │  │  │                   │
│   ┌────────────────────────────┐        │  │  │                   │
│   │      Code Reviewer         │◄───────╯  │  │                   │
│   └────────────────────────────┘           │  │                   │
│      │  │                                  │  │                   │
│      │  │   ┌──────────────────┐           │  │                   │
│      │  ╰──→│ Security Auditor │◄──────────╯  │                   │
│      │      └──────────────────┘              │                   │
│      │                                        │                   │
│      ╰── Findings → dotnet-developer ─────────╯                   │
│      ╰── Findings → powershell-engineer ──────╯                   │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

### Typische Flows

#### Flow 1: Neues Feature (Vision → MVP)

> Empfohlener Einstieg für neue Projekte oder größere Features.

```
1. Planning Agent     │ Zielbild beschreiben, Scope klären, Anforderungen definieren
       ↓ Handoff      │
2. App Architect      │ Solution-Struktur, Patterns, Technologie-Entscheidungen
       ↓ Handoff      │
3. Planning Agent     │ MVP-Stories schneiden, GitHub Issues erstellen
       ↓ Handoff      │
4. .NET Developer     │ Erste Story implementieren
       ↓ Handoff      │
5. TUnit Tester       │ Tests schreiben
       ↓ Handoff      │
6. Code Reviewer      │ Review durchführen
       ↓ Handoff      │
7. .NET Developer     │ Findings beheben (ggf. mehrere Iterationen)
```

#### Flow 2: CI/CD-Pipeline aufbauen

```
1. Planning Agent         │ Automations-Anforderungen definieren
       ↓ Handoff          │
2. Automation Architect   │ Workflow-Architektur, Matrix-Builds, Caching
       ↓ Handoff          │
3. Planning Agent         │ Tasks als Issues planen
       ↓ Handoff          │
4. PowerShell Engineer    │ Scripts und Workflows implementieren
       ↓ Handoff          │
5. Pester Tester          │ Tests schreiben
       ↓ Handoff          │
6. Code Reviewer          │ Review (Cross-Platform, Performance, Patterns)
```

#### Flow 3: Feature mit Datenbank

```
1. App Architect      │ Architektur mit EF Core Layer
       ↓ Handoff      │
2. Database Engineer  │ Schema, Migrations, Indizes
       ↓ Handoff      │
3. .NET Developer     │ Service/Repository Layer + API
       ↓ Handoff      │
4. .NET Developer     │ → Schema/Migration anfordern (bei Änderungen)
       ↓ Handoff      │
5. TUnit Tester       │ Integration Tests mit TestContainers
       ↓ Handoff      │
6. Code Reviewer      │ Review (N+1, AsNoTracking, Performance)
```

#### Flow 4: Security-Review-Zyklus

```
1. Code Reviewer          │ Review findet Sicherheitsbedenken
       ↓ Handoff          │
2. Security Auditor       │ OWASP-Audit, Dependency Scan
       ↓ Handoff          │
3. .NET Developer         │ Security-Fixes implementieren
       ↓ Handoff          │
4. Code Reviewer          │ Re-Review der Fixes
```

#### Flow 5: Bug-Analyse

```
1. Git Forensics      │ git blame, bisect — Ursache finden
       ↓ Handoff      │
2. .NET Developer     │ Bug fixen
       ↓ Handoff      │
3. TUnit Tester       │ Regression-Test schreiben
       ↓ Handoff      │
4. Code Reviewer      │ Fix reviewen
```

#### Flow 6: TDD-Zyklus (Test-Driven Development)

```
1. Planning Agent         │ Feature definieren, Acceptance Criteria
       ↓ Handoff          │
2. TUnit Tester (Modus 1) │ Test-Strategie, executable Test Skeletons
       ↓ Handoff          │
3. Planning Agent         │ Test Cases als Acceptance Criteria in Issues
       ↓ Handoff          │
4. TUnit Tester (Modus 2) │ RED — Failing Tests schreiben
       ↓ Handoff          │
5. .NET Developer         │ GREEN — Minimalen Produktionscode schreiben
       ↓ Handoff          │
6. TUnit Tester           │ REFACTOR — Tests verschärfen, Edge Cases
       ↓ Loop (max 3×)    │ zurück zu Schritt 4 bei neuen Tests
       ↓ Handoff          │
7. Code Reviewer          │ Finales Review
```

### Handoff-Matrix

Vollständige Übersicht aller Handoff-Verbindungen:

| Agent ↓ delegiert an → | planning | app-arch | auto-arch | dotnet | ps-eng | azure | db-eng | tunit | pester | sec-audit | reviewer | docs | git-for |
|------------------------|:--------:|:--------:|:---------:|:------:|:------:|:-----:|:------:|:-----:|:------:|:---------:|:--------:|:----:|:-------:|
| **Planning Agent**     |          | ✅       | ✅        |        |        |       |        | ✅    |        |           |          |      |         |
| **App Architect**      | ✅       |          |           | ✅     |        | ✅    | ✅     |       |        |           |          |      |         |
| **Automation Architect** | ✅     |          |           |        | ✅*    | ✅    |        |       |        |           |          |      | ✅      |
| **.NET Developer**     |          |          |           |        |        | ✅    | ✅     | ✅    |        |           | ✅       | ✅   |         |
| **PowerShell Engineer** |         |          |           |        |        |       |        |       | ✅     |           | ✅       | ✅   |         |
| **Azure Specialist**   |          |          |           | ✅     |        |       |        |       |        |           | ✅       |      |         |
| **Database Engineer**  |          |          |           | ✅     |        |       |        |       |        |           | ✅       |      |         |
| **TUnit Tester**       | ✅       |          |           | ✅     |        |       |        |       |        |           | ✅       |      |         |
| **Pester Tester**      |          |          |           |        | ✅     |       |        |       |        |           | ✅       |      |         |
| **Security Auditor**   |          |          |           | ✅     | ✅     |       |        |       |        |           |          |      |         |
| **Code Reviewer**      |          |          |           | ✅     | ✅     |       |        | ✅    | ✅     | ✅        |          |      |         |
| **Git Forensics**      |          |          |           | ✅     | ✅     |       |        |       |        |           |          |      |         |
| **Documentation**      |          |          |           |        |        |       |        |       |        |           |          |      |         |

_* Automation Architect delegiert an powershell-engineer für Script-Implementierung_

## Mitwirken

Siehe [CONTRIBUTING.md](CONTRIBUTING.md) für Richtlinien.

## Danksagung

OSS-Skills adaptiert von:
- [dotnet/skills](https://github.com/dotnet/skills) — Microsoft .NET Team
- [davidortinau/maui-skills](https://github.com/davidortinau/maui-skills) — David Ortinau (Microsoft PM)
- [Aaronontheweb/dotnet-skills](https://github.com/Aaronontheweb/dotnet-skills) — Aaron Stannard

## Lizenz

[MIT](LICENSE) © GrexyLoco


<!-- hybrid-rest-test -->

# 1. K.Agents — Spezialisierte AI-Agents fuer .NET, PowerShell & Azure

[![Release](https://img.shields.io/github/v/release/GrexyLoco/K.Agents?include_prereleases&label=version)](https://github.com/GrexyLoco/K.Agents/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Agents](https://img.shields.io/badge/Agents-16-blue)](.github/agents/)
[![Skills](https://img.shields.io/badge/Skills-49-green)](.github/skills/)

Kuratierte Sammlung von **16 Custom Agents** (15 spezialisierte + 1 Orchestrator), **49 Skills** und **2 MCP-Server** für VS Code Copilot, Visual Studio 2026 und Claude Code.
Optimiert für .NET 10, C# 14, Blazor, MAUI, PowerShell Core, GitHub Actions und Azure.

## 1.1 Inhaltsverzeichnis

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

## 1.2 Besonderheiten

- **TUnit** als .NET-Testframework (nicht xUnit/NUnit)
- **Pester 5.6.x** für PowerShell-Tests
- **ReleaseFlow-Integration** (K.Actions.ReleaseFlow Domänenwissen)
- **EU-Souveränitäts-Pflicht** beim Azure Specialist (immer Kosten dev/prod + Alternative)
- **Write-Host überall verboten** (auch CI-Scripts)
- **Deutsch** als Arbeitssprache für Doku, Issues, Commits

## 1.3 Installation

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

## 1.4 Agents

### 1.4.1 Einstieg (Orchestrator)
| Agent | Beschreibung | Model |
|-------|-------------|-------|
| [Orchestrator](plugins/kagents/agents/orchestrator.agent.md) | Automatisches Routing — analysiert Aufgabe und delegiert sofort | Haiku |

**Nutzung:** Orchestrator im Agent-Picker wählen oder direkt aufrufen:

| Platform | Aufruf |
|----------|--------|
| VS Code Copilot Chat | `@Orchestrator <Aufgabe>` im Chat-Eingabefeld |
| Claude Code (CLI) | `claude` starten → Shift+Tab → Agent-Picker → `Orchestrator` wählen |
| Visual Studio 2026 | Copilot Chat öffnen → Agent-Dropdown → `Orchestrator` wählen |

#### Warum Orchestrator?

K.Agents enthält 15 spezialisierte Agents — für neue User ist es nicht immer offensichtlich, welcher Agent für welche Aufgabe zuständig ist. Der Orchestrator nimmt diese kognitive Last ab: Einfach beschreiben, was gemacht werden soll, und der Orchestrator leitet automatisch an den richtigen Spezialisten weiter. Das kostet genau einen zusätzlichen Haiku-LLM-Call — schnell und günstig. Er ist der empfohlene Einstiegspunkt für alle K.Agents-Workflows.

#### Was der Orchestrator NICHT tut

- Führt niemals Tasks selbst aus — kein Code, keine Datei-Änderungen, keine technischen Erklärungen
- Beantwortet keine fachlichen oder technischen Fragen direkt
- Stellt maximal eine Rückfrage bei echter Unklarheit, delegiert danach immer sofort
- Hat keine Tools — kann ausschließlich über Handoffs an Spezialisten weiterleiten

#### Aufrufbeispiele

| Eingabe | Ziel-Agent | Begründung |
|---------|------------|------------|
| "Implementiere einen User-Service mit EF Core Repository-Pattern" | `dotnet-developer` | C#/.NET Implementierungsaufgabe |
| "Schreibe Pester-Tests für das Deployment-Script" | `pester-tester` | PowerShell-Tests mit Pester-Kontext |
| "Plane das Feature für automatische Benachrichtigungen als GitHub Issues" | `planning` | Feature-Planung und Issue-Erstellung |
| "Welche Azure-Ressourcen brauchen wir für .NET Aspire mit EU-Daten?" | `azure-specialist` | Azure/Aspire + EU-Souveränitätsfrage |
| "Review meinen Code und schreib danach die Docs" | `code-reviewer` | Code Review zuerst — der macht dann Handoff an `documentation` |

#### Orchestrator vs. direkter Agent-Aufruf

| Situation | Empfehlung |
|-----------|-----------|
| Aufgabe ist klar beschreibbar, aber welcher Agent zuständig ist, ist unklar | Orchestrator nutzen |
| Aufgabe ergibt sich aus einem laufenden Flow (Handoff-Button sichtbar) | Handoff direkt nutzen |
| Zuständiger Spezialist ist bekannt und 1 LLM-Call soll gespart werden | Direkt den Spezialisten aufrufen |

#### Integration in K.Agents-Flows

Der Orchestrator ist der empfohlene Einstieg für alle Flows (Feature-Flow, CI/CD-Flow, TDD-Zyklus etc.). Folgeschritte innerhalb eines Flows — z.B. vom Planning Agent weiter zum App Architect — laufen über die eingebauten Handoff-Buttons direkt zwischen den Spezialisten, ohne erneuten Orchestrator-Umweg.

### 1.4.2 Strategie & Planung
| Agent | Beschreibung | Model |
|-------|-------------|-------|
| [Planning Agent](plugins/kagents/agents/planning.agent.md) | Feature-Planung → GitHub Issues/Milestones | Opus |
| [App Architect](plugins/kagents/agents/app-architect.agent.md) | .NET/Blazor/MAUI Architektur, Modular Monolith | Opus |
| [Automation Architect](plugins/kagents/agents/automation-architect.agent.md) | CI/CD, Workflows, Release-Strategie | Opus |

### 1.4.3 Implementierung
| Agent | Beschreibung | Model |
|-------|-------------|-------|
| [.NET Developer](plugins/kagents/agents/dotnet-developer.agent.md) | C# 14, Blazor, MAUI, APIs | Sonnet |
| [PowerShell Engineer](plugins/kagents/agents/powershell-engineer.agent.md) | Cross-Platform PS Core, GitHub Actions | Sonnet |
| [Azure Specialist](plugins/kagents/agents/azure-specialist.agent.md) | Aspire, Monitoring + EU-Alternativen | Sonnet |
| [Database Engineer](plugins/kagents/agents/database-engineer.agent.md) | EF Core, Migrations, Performance | Sonnet |

### 1.4.4 Qualitätssicherung
| Agent | Beschreibung | Model |
|-------|-------------|-------|
| [TUnit Tester](plugins/kagents/agents/tunit-tester.agent.md) | .NET Tests mit TUnit | Sonnet |
| [Pester Tester](plugins/kagents/agents/pester-tester.agent.md) | PowerShell Tests mit Pester 5.6 | Sonnet |
| [Security Auditor](plugins/kagents/agents/security-auditor.agent.md) | OWASP, Dependency Scanning | Sonnet |
| [Code Reviewer](plugins/kagents/agents/code-reviewer.agent.md) | Patterns, Performance, Architektur | Opus |

### 1.4.5 Querschnitt
| Agent | Beschreibung | Model |
|-------|-------------|-------|
| [Documentation](plugins/kagents/agents/documentation.agent.md) | README, Changelog, API-Docs | Sonnet |
| [Git Forensics](plugins/kagents/agents/git-forensics.agent.md) | Blame, Bisect, Conventional Commits | Sonnet |

## 1.5 Skills

### 1.5.1 Eigene Skills (17)
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

### 1.5.2 OSS-adaptierte Skills (10)
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

## 1.6 MCP-Server

Das Plugin liefert zwei MCP-Server mit, die automatisch im Plugin-System (VS Code, Claude Code, Copilot CLI) gestartet werden:

| Server | Typ | Funktion | Tools |
|--------|-----|----------|-------|
| **Microsoft Learn** | HTTP | Offizielle Microsoft-Dokumentation und Code-Beispiele | `microsoft_docs_search`, `microsoft_docs_fetch`, `microsoft_code_sample_search` |
| **GitHub** | HTTP | Issues, PRs, Repos, Code-Suche, Advisory Database | `list_issues`, `search_code`, `create_pull_request`, u.v.m. |

> **Voraussetzung GitHub MCP:** `gh auth login` muss einmalig ausgeführt worden sein.

> **Hinweis:** MCP-Server werden von Visual Studio 2026 nicht unterstützt. Siehe [INSTALLATION.md](INSTALLATION.md#was-das-plugin-mitliefert) für Details.

## 1.7 Kompatibilität

| Umgebung | Status | Installation | Hooks & MCPs |
|----------|--------|-------------|--------------|
| VS Code + GitHub Copilot | ✅ Primär | Plugin Marketplace oder Settings | ✅ via Plugin |
| Visual Studio 2026 (ab 18.5) | ✅ | [Install-Script](scripts/Install-KAgentsVS.ps1) (User-Level Copy) | ❌ nicht unterstützt |
| Claude Code | ✅ | Plugin Marketplace | ✅ via Plugin |
| Copilot CLI | ✅ | Plugin Marketplace | ✅ via Plugin |

> **Hinweis:** VS Code und Copilot CLI teilen Plugin-Discovery. Visual Studio 2026 nutzt dagegen ein eigenes Discovery-System und erkennt diese Plugins nicht. [Details → INSTALLATION.md](INSTALLATION.md#visual-studio-2026)

## 1.8 Agent-Workflow & Handoff-Flows

Die Agents sind über **Handoff-Buttons** miteinander verknüpft. Nach jeder Agent-Antwort erscheinen Buttons, die zum nächsten passenden Agent weiterleiten — inklusive Kontext aus der bisherigen Konversation.

### 1.8.1 Übersichtsgraph

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

### 1.8.2 Typische Flows

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

### 1.8.3 Handoff-Matrix

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

## 1.9 Mitwirken

Siehe [CONTRIBUTING.md](CONTRIBUTING.md) für Richtlinien.

### 1.9.1 Kritische Repo-Dateien

#### `.claude-plugin/marketplace.json`

Claude Code sucht beim Hinzufügen eines GitHub-Repos als Marketplace zwingend unter `.claude-plugin/marketplace.json`. Ohne diese Datei schlägt die Installation fehl:

```text
Plugin "kagents" not found in marketplace "kagents"
```

Das Verzeichnis `.claude-plugin/` darf **nicht entfernt** werden — auch nicht bei Strukturbereinigungen. Hintergrund: [Issue #149](https://github.com/GrexyLoco/K.Agents/issues/149), [Claude Code Docs](https://code.claude.com/docs/en/discover-plugins).

## 1.10 Danksagung

OSS-Skills adaptiert von:
- [dotnet/skills](https://github.com/dotnet/skills) — Microsoft .NET Team
- [davidortinau/maui-skills](https://github.com/davidortinau/maui-skills) — David Ortinau (Microsoft PM)
- [Aaronontheweb/dotnet-skills](https://github.com/Aaronontheweb/dotnet-skills) — Aaron Stannard

## 1.11 Lizenz

[MIT](LICENSE) © GrexyLoco


<!-- hybrid-rest-test -->

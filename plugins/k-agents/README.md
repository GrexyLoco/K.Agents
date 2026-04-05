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

## Logging & Audit-Trail

K.Agents loggt alle Agent-Aktivitaeten automatisch via Hooks.

### Log-Verzeichnis

```
~/.k-agents/logs/
├── 2026-04-05.jsonl
├── 2026-04-06.jsonl
└── ...
```

Format: **JSONL** — eine JSON-Zeile pro Event, ein File pro Tag.

### Events

| Event | Trigger |
|-------|---------|
| `agent_start` | Agent beginnt Aufgabe (pre_tool_call) |
| `agent_handoff` | Delegation an anderen Agenten |
| `agent_complete` | Agent fertig |
| `error` | Fehler aufgetreten |
| `fallback` | CLI-Wechsel wegen Rate Limit |

### Log analysieren

```powershell
# Alle Fehler von heute
Get-Content (Join-Path $env:USERPROFILE '.k-agents' 'logs' "$(Get-Date -Format 'yyyy-MM-dd').jsonl") |
    ConvertFrom-Json |
    Where-Object { $_.event -eq 'error' }

# Haeufigkeit pro Agent
Get-Content (Join-Path $env:USERPROFILE '.k-agents' 'logs' '*.jsonl') |
    ConvertFrom-Json |
    Group-Object agent |
    Sort-Object Count -Descending
```

### Log-Rotation

```powershell
# Logs aelter als 30 Tage loeschen
& (Join-Path $PSScriptRoot 'scripts' 'cleanup-logs.ps1') -RetentionDays 30
```

## Lizenz

MIT — Siehe [LICENSE](../../LICENSE) für Details.

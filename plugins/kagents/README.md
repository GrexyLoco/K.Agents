# 1. K.Agents

**16 AI-Agents (15 spezialisierte + 1 Orchestrator) und 49 Skills** für .NET 10, C# 14, Blazor, MAUI, PowerShell Core, GitHub Actions und Azure.

## 1.1 Überblick

Kuratierte Sammlung von Custom Agents und Skills für VS Code Copilot, Visual Studio 2026 und Claude Code. Jeder Agent hat eine klar definierte Rolle mit Handoff-Buttons zur nahtlosen Zusammenarbeit.

## 1.2 Agents

### 1.2.1 Einstieg

| Agent | Beschreibung | Model |
|-------|-------------|-------|
| Orchestrator | Automatisches Routing — analysiert Aufgabe und delegiert sofort | Haiku |

### 1.2.2 Strategie & Planung

| Agent | Beschreibung | Model |
|-------|-------------|-------|
| Planning Agent | Feature-Planung → GitHub Issues/Milestones | Opus |
| App Architect | .NET/Blazor/MAUI Architektur, Modular Monolith | Opus |
| Automation Architect | CI/CD, Workflows, Release-Strategie | Opus |

### 1.2.3 Implementierung

| Agent | Beschreibung | Model |
|-------|-------------|-------|
| .NET Developer | C# 14, Blazor, MAUI, APIs | Sonnet |
| PowerShell Engineer | Cross-Platform PS Core, GitHub Actions | Sonnet |
| Azure Specialist | Aspire, Monitoring + EU-Alternativen | Sonnet |
| Database Engineer | EF Core, Migrations, Performance | Sonnet |

### 1.2.4 Qualitätssicherung

| Agent | Beschreibung | Model |
|-------|-------------|-------|
| TUnit Tester | .NET Tests mit TUnit | Sonnet |
| Pester Tester | PowerShell Tests mit Pester 5.6 | Sonnet |
| Security Auditor | OWASP, Dependency Scanning | Sonnet |
| Code Reviewer | Patterns, Performance, Architektur | Opus |

### 1.2.5 Querschnitt

| Agent | Beschreibung | Model |
|-------|-------------|-------|
| Documentation | README, Changelog, API-Docs | Sonnet |
| Git Forensics | Blame, Bisect, Conventional Commits | Sonnet |

## 1.3 Skills (49)

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
| Security | `owasp-dotnet`, `security-audit` |
| Release | `release-management`, `conventional-commits`, `releaseflow-domain`, `releaseflow-coding-patterns`, `releaseflow-train-status`, `releaseflow-conflict-fix`, `releaseflow-push` |
| Build | `dotnet-build-diagnosis`, `dotnet-aot-compat` |
| Architektur | `app-architecture`, `automation-architecture` |
| VCS/Git | `git-forensics` |
| Dokumentation | `documentation-patterns` |

## 1.4 Tools

Ausführbare PowerShell-Scripts für KI-Agenten zur deterministischen ReleaseFlow-Steuerung.

| Tool | Beschreibung |
|------|-------------|
| `releaseflow/Get-ReleaseTrain` | Train-Status, Phase, erlaubte Branches, Milestone, blockierende Issues |
| `releaseflow/Invoke-ReleaseConflictFix` | ReleaseFlow-spezifischer Merge-Konflikt-Workflow |

## 1.5 Skill-Mechanismus

Skills werden über zwei Mechanismen geladen:
- **`skills:` Frontmatter** (Claude Code): Automatisches Laden beim Agent-Start
- **Markdown-Links** im Agent-Body (VS Code Copilot): Via `## Skill-Referenzen` Sektion

Beide Mechanismen verwenden denselben `SKILL.md`-Inhalt — das Verhalten ist plattformunabhängig identisch.

## 1.6 Besonderheiten

- **TUnit** als .NET-Testframework (nicht xUnit/NUnit)
- **Pester 5.6.x** für PowerShell-Tests
- **ReleaseFlow-Integration** (K.Actions.ReleaseFlow Domänenwissen)
- **EU-Souveränitäts-Pflicht** beim Azure Specialist
- **Write-Host überall verboten** (auch CI-Scripts)
- **Deutsch** als Arbeitssprache für Doku, Issues, Commits

## 1.7 Copilot Chat Integration

K.Agents funktioniert am besten, wenn Copilot Chat weiss, wie es die CLIs und den Orchestrator nutzen soll.

### 1.7.1 Option A: Template kopieren (empfohlen)

```powershell
# Fuer ein einzelnes Repo
& (Join-Path $PSScriptRoot 'scripts' 'Setup-Instructions.ps1') -Path 'C:\repos\MeinProjekt'

# Global fuer alle Repos
& (Join-Path $PSScriptRoot 'scripts' 'Setup-Instructions.ps1')
```

Passe danach den Abschnitt `## Projekt-Kontext` in der installierten Datei an.

### 1.7.2 Option B: Manuell kopieren

```powershell
# Repo-spezifisch
Copy-Item (Join-Path $PSScriptRoot 'templates' 'copilot-instructions.md') `
          (Join-Path 'C:\repos\MeinProjekt' '.github' 'copilot-instructions.md')

# Global
Copy-Item (Join-Path $PSScriptRoot 'templates' 'copilot-instructions.md') `
          (Join-Path $env:USERPROFILE '.github' 'copilot-instructions.md')
```

### 1.7.3 Verifizieren

Nach Setup, frage Copilot Chat:
> "Welche CLIs und Agenten stehen dir zur Verfuegung?"

Die Antwort sollte Claude CLI, Copilot CLI und den Orchestrator erwaehnen.

## 1.8 MCP-Server

K.Agents bringt vorkonfigurierte MCP-Server mit. Bei Plugin-Installation werden alle MCPs automatisch registriert.

### 1.8.1 Inkludierte MCPs

| MCP | Typ | Funktion | Genutzt von |
|-----|-----|----------|-------------|
| **Microsoft Learn** | HTTP | Offizielle MS/Azure Dokumentation, Code-Samples | `app-architect`, `dotnet-developer`, `azure-specialist`, `documentation` |
| **NuGet** | STDIO | Package-Management, Vulnerabilities, READMEs | `dotnet-developer`, `security-auditor`, `app-architect` |
| **GitHub** | STDIO | Repos, Issues, PRs, Code Search, Workflows | `planning`, `code-reviewer`, `git-forensics`, `automation-architect` |

### 1.8.2 MCP-Status pruefen

```bash
# Claude CLI
claude mcp list

# Copilot CLI
copilot mcp list
```

### 1.8.3 Manuell MCP hinzufuegen

Falls ein MCP nach Installation fehlt:

```bash
# Microsoft Learn (HTTP, keine lokale Installation noetig)
claude mcp add microsoftdocs/mcp --url https://learn.microsoft.com/api/mcp

# NuGet (benoetigt .NET SDK / dnx)
claude mcp add com.microsoft/nuget

# GitHub (benoetigt lokale github-mcp-server Installation)
claude mcp add io.github.github/github-mcp-server
```

### 1.8.4 GitHub MCP: Credentials

Standard: CLI-Auth via `gh auth token`.
Override: Umgebungsvariable `GITHUB_TOKEN` setzen.

```powershell
# GITHUB_TOKEN setzen (optional)
$env:GITHUB_TOKEN = (gh auth token)
```

## 1.9 Logging & Audit-Trail

K.Agents loggt alle Agent-Aktivitaeten automatisch via Hooks.

### 1.9.1 Log-Verzeichnis

```
${CLAUDE_PLUGIN_ROOT}/logs/
├── 2026-04-05.jsonl
├── 2026-04-06.jsonl
└── ...
```

Format: **JSONL** — eine JSON-Zeile pro Event, ein File pro Tag.

### 1.9.2 Events

| Event | Trigger |
|-------|---------|
| `agent_start` | Agent beginnt Aufgabe (pre_tool_call) |
| `agent_handoff` | Delegation an anderen Agenten |
| `agent_complete` | Agent fertig |
| `error` | Fehler aufgetreten |
| `fallback` | CLI-Wechsel wegen Rate Limit |

### 1.9.3 Log analysieren

```powershell
# Alle Fehler von heute
Get-Content (Join-Path $env:CLAUDE_PLUGIN_ROOT 'logs' "$(Get-Date -Format 'yyyy-MM-dd').jsonl") |
    ConvertFrom-Json |
    Where-Object { $_.event -eq 'error' }

# Haeufigkeit pro Agent
Get-Content (Join-Path $env:CLAUDE_PLUGIN_ROOT 'logs' '*.jsonl') |
    ConvertFrom-Json |
    Group-Object agent |
    Sort-Object Count -Descending
```

### 1.9.4 Log-Rotation

```powershell
# Logs aelter als 30 Tage loeschen
& (Join-Path $PSScriptRoot 'scripts' 'cleanup-logs.ps1') -RetentionDays 30
```

## 1.10 ReleaseFlow-Guardrail

K.Agents schuetzt den [K.Actions.ReleaseFlow](https://github.com/GrexyLoco/K.Actions.ReleaseFlow)-Prozess
automatisch via PreToolUse-Hook. Der Guardrail blockiert direkte `master`/`main`-Merges, die den
Branching-Prozess umgehen wuerden.

### 1.10.1 Geschuetzte Kommandos

| Kommando | Geprueft | Erlaubt |
|----------|----------|---------|
| `gh pr create --base master` | Head-Branch muss `release/v*` sein | Nur Stable-PRs |
| `gh pr create` (ohne `--base`) | Warnung: Default-Target koennte master sein | Explizit `--base` setzen |
| `gh pr merge` | Head-Branch muss `release/v*` sein | Nur von release-Branches |

### 1.10.2 ReleaseFlow-Branching-Modell

```
feature/* oder fix/*  →  dev/vX.Y.Z  →  release/vX.Y.Z  →  master
```

### 1.10.3 Repo-Erkennung

Der Guardrail ist nur aktiv in Repos, die ReleaseFlow verwenden. Erkennungs-Marker:

- `.releaseflow` Datei im Repo-Root
- `releaseflow.json` Datei im Repo-Root
- `action.yml` mit `K.Actions.ReleaseFlow`-Referenz
- `.github/workflows/*.yml` mit `K.Actions.ReleaseFlow`-Referenz

### 1.10.4 Break-Glass

Wenn ein direkter Master-Merge beabsichtigt ist (z.B. Hotfix ausserhalb ReleaseFlow), kann der
Guardrail mit der Umgebungsvariable `RELEASEFLOW_BYPASS=1` umgangen werden:

```powershell
# Break-Glass aktivieren (nur fuer aktuelle Shell-Session)
$env:RELEASEFLOW_BYPASS = '1'

# Kommando ausfuehren
gh pr create --base master --title 'Emergency Fix'

# Break-Glass danach deaktivieren
Remove-Item Env:RELEASEFLOW_BYPASS
```

> **Hinweis:** Jede Bypass-Nutzung wird ins Audit-Log geschrieben (`event: releaseflow_guardrail_bypass`).

### 1.10.5 Guardrail deaktivieren

Der Guardrail ist Teil der K.Agents Hooks. Er kann per Uninstall-Script deaktiviert werden:

```powershell
& (Join-Path $PSScriptRoot 'scripts' 'Uninstall-Hooks.ps1')
```

## 1.11 Lizenz

MIT — Siehe [LICENSE](../../LICENSE) für Details.

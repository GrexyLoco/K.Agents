# 1. Copilot Instructions — K.Agents Integration

## 1.1 K.Agents Uebersicht

Dieses Projekt nutzt das **K.Agents Plugin** mit:
- 16 Agenten (15 spezialisierte + 1 Orchestrator)
- 49 Skills (Domain-spezifisches Wissen)
- 2 MCP-Server (Microsoft Learn, GitHub)
- Logging-Hooks fuer Audit-Trail

### 1.1.1 Plattform-Kompatibilitaet

| Feature | Claude Code | VS Code Copilot Chat | VS 2026 |
|---|---|---|---|
| Agents (16) | Automatisch via Plugin | Automatisch via Plugin | `Install-KAgentsVS.ps1` |
| Skills (49) | Automatisch via Plugin | Automatisch via Plugin | `Install-KAgentsVS.ps1` |
| MCP-Server (2) | Automatisch via Plugin | Automatisch via Plugin | Nicht verfuegbar |
| Hooks/Logging | Automatisch via Plugin | Automatisch via Plugin | Nicht verfuegbar |
| Instructions | `Setup-Instructions.ps1` | `Setup-Instructions.ps1` | `Install-KAgentsVS.ps1` |

### 1.1.2 Agent-Routing

Der **Orchestrator** ist der empfohlene Einstiegspunkt — er analysiert die Aufgabe und delegiert via Handoff an den passenden Agenten:

| Aufgaben-Typ | Ziel-Agent |
|---|---|
| Feature planen, Issues erstellen | `planning` |
| .NET/Blazor/MAUI Architektur | `app-architect` |
| CI/CD, Release-Strategie | `automation-architect` |
| C#/.NET Code schreiben | `dotnet-developer` |
| .NET Architektur entscheiden | `dotnet-architect` |
| PowerShell Scripts | `powershell-engineer` |
| Azure, Aspire, Monitoring | `azure-specialist` |
| EF Core, Datenbank | `database-engineer` |
| .NET Tests (TUnit) | `tunit-tester` |
| PowerShell Tests (Pester) | `pester-tester` |
| Security-Audit | `security-auditor` |
| Code Review | `code-reviewer` |
| Dokumentation | `documentation` |
| Git-Historie | `git-forensics` |
| Commit-/Nachrichten-Polishing | `commit-messenger` |

## 1.2 Projekt-Kontext

<!-- HIER PROJEKT-SPEZIFISCHE INFOS EINFUEGEN -->

- **Runtime:** .NET 10, C# 14
- **Frameworks:** <!-- Blazor / MAUI / API / ... -->
- **Testing:** TUnit (.NET), Pester (PowerShell)
- **CI/CD:** GitHub Actions
- **Release-Prozess:** K.Actions.ReleaseFlow

## 1.3 Globale Regeln

### 1.3.1 Sprache
- Dokumentation, Issues, Commits: **Deutsch**
- Code (Variablen, Klassen, Methoden): **Englisch**

### 1.3.2 Commits
Conventional Commits: `<type>(<scope>): <beschreibung>`
Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`

### 1.3.3 Code-Stil
- **C#:** File-scoped Namespaces, Nullable Reference Types, Primary Constructors, Records fuer DTOs
- **PowerShell:** `#Requires -Version 7.4`, `Set-StrictMode -Version Latest`, kein `Write-Host`, `Join-Path` fuer Pfade

### 1.3.4 Testing
- **.NET:** Ausschliesslich TUnit (nicht xUnit, NUnit, MSTest)
- **PowerShell:** Ausschliesslich Pester 5.6.x

### 1.3.5 Azure
Bei jeder Azure-Empfehlung muss eine EU-souveraene Alternative mit Kostenvergleich (Entwicklung + Produktion getrennt) angegeben werden.

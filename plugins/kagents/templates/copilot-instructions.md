# Copilot Instructions — K.Agents Integration

## K.Agents Uebersicht

Dieses Projekt nutzt das **K.Agents Plugin** mit:
- 14 Agenten (13 spezialisierte + 1 Orchestrator)
- 32 Skills (Domain-spezifisches Wissen)
- 2 MCP-Server (Microsoft Learn, GitHub)
- Logging-Hooks fuer Audit-Trail

### Plattform-Kompatibilitaet

| Feature | Claude Code | VS Code Copilot Chat | VS 2026 |
|---|---|---|---|
| Agents (14) | Automatisch via Plugin | Automatisch via Plugin | `Install-KAgentsVS.ps1` |
| Skills (32) | Automatisch via Plugin | Automatisch via Plugin | `Install-KAgentsVS.ps1` |
| MCP-Server (2) | Automatisch via Plugin | Automatisch via Plugin | Nicht verfuegbar |
| Hooks/Logging | Automatisch via Plugin | Automatisch via Plugin | Nicht verfuegbar |
| Instructions | `Setup-Instructions.ps1` | `Setup-Instructions.ps1` | `Install-KAgentsVS.ps1` |

### Agent-Routing

Der **Orchestrator** ist der empfohlene Einstiegspunkt — er analysiert die Aufgabe und delegiert via Handoff an den passenden Agenten:

| Aufgaben-Typ | Ziel-Agent |
|---|---|
| Feature planen, Issues erstellen | `planning` |
| .NET/Blazor/MAUI Architektur | `app-architect` |
| CI/CD, Release-Strategie | `automation-architect` |
| C#/.NET Code schreiben | `dotnet-developer` |
| PowerShell Scripts | `powershell-engineer` |
| Azure, Aspire, Monitoring | `azure-specialist` |
| EF Core, Datenbank | `database-engineer` |
| .NET Tests (TUnit) | `tunit-tester` |
| PowerShell Tests (Pester) | `pester-tester` |
| Security-Audit | `security-auditor` |
| Code Review | `code-reviewer` |
| Dokumentation | `documentation` |
| Git-Historie | `git-forensics` |

## Projekt-Kontext

<!-- HIER PROJEKT-SPEZIFISCHE INFOS EINFUEGEN -->

- **Runtime:** .NET 10, C# 14
- **Frameworks:** <!-- Blazor / MAUI / API / ... -->
- **Testing:** TUnit (.NET), Pester (PowerShell)
- **CI/CD:** GitHub Actions
- **Release-Prozess:** K.Actions.ReleaseFlow

## Globale Regeln

### Sprache
- Dokumentation, Issues, Commits: **Deutsch**
- Code (Variablen, Klassen, Methoden): **Englisch**

### Commits
Conventional Commits: `<type>(<scope>): <beschreibung>`
Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`

### Code-Stil
- **C#:** File-scoped Namespaces, Nullable Reference Types, Primary Constructors, Records fuer DTOs
- **PowerShell:** `#Requires -Version 7.4`, `Set-StrictMode -Version Latest`, kein `Write-Host`, `Join-Path` fuer Pfade

### Testing
- **.NET:** Ausschliesslich TUnit (nicht xUnit, NUnit, MSTest)
- **PowerShell:** Ausschliesslich Pester 5.6.x

### Azure
Bei jeder Azure-Empfehlung muss eine EU-souveraene Alternative mit Kostenvergleich (Entwicklung + Produktion getrennt) angegeben werden.

# AGENTS.md – Globale Agent-Anweisungen

## Projekt-Kontext

Diese Codebase gehört zu einer Software-Entwicklungsabteilung mit folgenden Schwerpunkten:

- **Applikationsentwicklung:** Blazor (Server/WASM/Hybrid), .NET MAUI, ASP.NET Core Minimal APIs
- **Runtime:** .NET 10, C# 14
- **Automation:** GitHub Actions, PowerShell Core (strikt cross-platform)
- **Cloud:** Azure (bestehende Subscription), .NET Aspire
- **Observability:** Application Insights, OpenTelemetry, Aspire Dashboard
- **Testing:** TUnit (.NET), Pester 5.6.x (PowerShell)
- **Projektmanagement:** GitHub Issues, Milestones, Labels
- **Versioning:** SemVer, Conventional Commits

## Agent-Routing

Dieses Projekt verfügt über 14 Agents (13 spezialisierte + 1 Orchestrator). Der **Orchestrator** ist der empfohlene Einstiegspunkt — er analysiert die Aufgabe und delegiert automatisch an den passenden Agenten.

Wähle den Orchestrator im **Agent-Picker** (Copilot Chat, Claude Code).

**Beispiele — Orchestrator leitet automatisch weiter:**

| Eingabe | Ziel-Agent |
|---------|------------|
| "Implementiere einen User-Service mit EF Core Repository-Pattern" | `dotnet-developer` |
| "Schreibe Pester-Tests für das Deployment-Script" | `pester-tester` |
| "Welche Azure-Ressourcen brauchen wir für .NET Aspire mit EU-Daten?" | `azure-specialist` |

Wähle direkt einen spezialisierten Agenten, wenn der Aufgabentyp klar ist:

| Aufgabe | Agent |
|---------|-------|
| Beliebige Aufgabe (automatisches Routing) | `orchestrator` |
| Feature planen, Issues erstellen | `planning` |
| .NET/Blazor/MAUI Architektur entscheiden | `app-architect` |
| CI/CD-Pipelines, Release-Strategie entwerfen | `automation-architect` |
| C#/.NET Code schreiben | `dotnet-developer` |
| PowerShell Scripts/Module implementieren | `powershell-engineer` |
| Azure, Aspire, Monitoring konfigurieren | `azure-specialist` |
| EF Core Schema, Migrations, Queries | `database-engineer` |
| .NET Tests mit TUnit schreiben | `tunit-tester` |
| PowerShell Tests mit Pester schreiben | `pester-tester` |
| Security-Audit durchführen | `security-auditor` |
| Code Review | `code-reviewer` |
| Dokumentation erstellen | `documentation` |
| Git-Historie analysieren, Commits prüfen | `git-forensics` |

## Globale Regeln (gelten für ALLE Agents)

### Sprache
- **Dokumentation, Issues, Commits, Kommentare:** Deutsch
- **Code (Variablen, Klassen, Methoden):** Englisch
- **Dateinamen:** Englisch

### Commit-Konventionen
Alle Commits folgen **Conventional Commits**:
```
<type>(<scope>): <beschreibung>
```
Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `ci`
Scopes: `blazor`, `maui`, `api`, `efcore`, `aspire`, `ci`, `ps`, `infra`, `docs`

### Code-Stil
- **C#:** File-scoped Namespaces, Nullable Reference Types aktiviert, Primary Constructors, Records für DTOs
- **PowerShell:** `Write-Host` verboten (überall, auch CI-Scripts), `Join-Path` für Pfade, strikt cross-platform
- **PowerShell Header:** `#Requires -Version 7.4` + `Set-StrictMode -Version Latest` + `$ErrorActionPreference = 'Stop'`
- **YAML:** 2 Spaces Indentation, `shell: pwsh` (nicht `powershell`)

### Release-Prozess (K.Actions.ReleaseFlow)
Dieses Projekt nutzt K.Actions.ReleaseFlow für automatisierte Release-Orchestrierung:
- **Branching:** `feature/*` → `dev/vX.Y.Z` → `release/vX.Y.Z` → `main`
- **Phasen:** Alpha → Freeze → Beta → Stable (mit Backflow PRs)
- **Guardrails G1-G5** verhindern Prozessverletzungen
- **GitHub App Token** statt PATs für CI/CD
- **Quality Gate:** GitLeaks → PSScriptAnalyzer → Pester → Evaluation
- Siehe Skills `releaseflow-domain` und `releaseflow-coding-patterns` für Details

### Testing
- **.NET Tests:** Ausschließlich TUnit (nicht xUnit, NUnit, MSTest)
- **PowerShell Tests:** Ausschließlich Pester 5.6.x (nicht Pester 4 Syntax)
- **CI:** Tests müssen cross-platform laufen (Windows + Linux mindestens)

### Azure & Souveränität
Bei jeder Azure-Empfehlung muss eine EU-souveräne Alternative mit Kostenvergleich (Entwicklung + Produktion getrennt) genannt werden.

### Qualitätssicherung
Validation Loop: QS-Agents (TUnit Tester, Pester Tester, Security Auditor, Code Reviewer) können Findings zurück an Implementierungs-Agents delegieren. Der Kreislauf läuft bis alle Findings behoben sind.

### Keine Annahmen
Wenn etwas unklar ist: **fragen**, nicht raten. Kein Overengineering, kein Gold-Plating.

# 1. AGENTS.md – Globale Agent-Anweisungen

## 1.1 Projekt-Kontext

Diese Codebase gehört zu einer Software-Entwicklungsabteilung mit folgenden Schwerpunkten:

- **Applikationsentwicklung:** Blazor (Server/WASM/Hybrid), .NET MAUI, ASP.NET Core Minimal APIs
- **Runtime:** .NET 10, C# 14
- **Automation:** GitHub Actions, PowerShell Core (strikt cross-platform)
- **Cloud:** Azure (bestehende Subscription), .NET Aspire
- **Observability:** Application Insights, OpenTelemetry, Aspire Dashboard
- **Testing:** TUnit (.NET), Pester 5.6.x (PowerShell)
- **Projektmanagement:** GitHub Issues, Milestones, Labels
- **Versioning:** SemVer, Conventional Commits

## 1.2 Agent-Routing

Dieses Projekt verfügt über 16 Agents (15 spezialisierte + 1 Orchestrator). Der **Orchestrator** ist der empfohlene Einstiegspunkt — er analysiert die Aufgabe und delegiert automatisch an den passenden Agenten.

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

## 1.3 Globale Regeln (gelten für ALLE Agents)

### 1.3.1 Sprache
- **Dokumentation, Issues, Commits, Kommentare:** Deutsch
- **Code (Variablen, Klassen, Methoden):** Englisch
- **Dateinamen:** Englisch

### 1.3.2 Commit-Konventionen
Alle Commits folgen **Conventional Commits**:
```
<type>(<scope>): <beschreibung>
```
Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `ci`
Scopes: `blazor`, `maui`, `api`, `efcore`, `aspire`, `ci`, `ps`, `infra`, `docs`

### 1.3.3 Code-Stil
- **C#:** File-scoped Namespaces, Nullable Reference Types aktiviert, Primary Constructors, Records für DTOs
- **PowerShell:** `Write-Host` verboten (überall, auch CI-Scripts), `Join-Path` für Pfade, strikt cross-platform
- **PowerShell Header:** `#Requires -Version 7.4` + `Set-StrictMode -Version Latest` + `$ErrorActionPreference = 'Stop'`
- **YAML:** 2 Spaces Indentation, `shell: pwsh` (nicht `powershell`)

### 1.3.4 Release-Prozess (K.Actions.ReleaseFlow)
Dieses Projekt nutzt K.Actions.ReleaseFlow für automatisierte Release-Orchestrierung:
- **Branching:** `feature/*` → `dev/vX.Y.Z` → `release/vX.Y.Z` → `main`
- **Phasen:** Alpha → Freeze → Beta → Stable (mit Backflow PRs)
- **Guardrails G1-G5** verhindern Prozessverletzungen
- **GitHub App Token** statt PATs für CI/CD
- **Quality Gate:** GitLeaks → PSScriptAnalyzer → Pester → Evaluation
- Siehe Skills `releaseflow-domain` und `releaseflow-coding-patterns` für Details
- Skills: `releaseflow-train-status`, `releaseflow-push`, `releaseflow-conflict-fix` — KI-Interface für ReleaseFlow-Aktionen

### 1.3.5 Testing
- **.NET Tests:** Ausschließlich TUnit (nicht xUnit, NUnit, MSTest)
- **PowerShell Tests:** Ausschließlich Pester 5.6.x (nicht Pester 4 Syntax)
- **CI:** Tests müssen cross-platform laufen (Windows + Linux mindestens)

### 1.3.6 Azure & Souveränität
Bei jeder Azure-Empfehlung muss eine EU-souveräne Alternative mit Kostenvergleich (Entwicklung + Produktion getrennt) genannt werden.

### 1.3.7 Qualitätssicherung
Validation Loop: QS-Agents (TUnit Tester, Pester Tester, Security Auditor, Code Reviewer) können Findings zurück an Implementierungs-Agents delegieren. Der Kreislauf läuft bis alle Findings behoben sind.

### 1.3.8 Keine Implementierung ohne Issue
Vor dem Start jeder Implementierung muss eine GitHub-Issue-Nummer vorliegen. Fehlt sie, fragt der Agent nach oder schlägt vor, zuerst ein Issue zu erstellen (via `planning`-Agent). Bei Einstieg über den `orchestrator` darf nur an einen Implementierungs-Agenten delegiert werden, wenn eine Issue-Nummer vorliegt. Gilt für alle Implementierungs-Agents: `dotnet-developer`, `powershell-engineer`, `tunit-tester`, `pester-tester`.

### 1.3.9 Keine Annahmen
Wenn etwas unklar ist: **fragen**, nicht raten. Kein Overengineering, kein Gold-Plating.

# ADR-0001: Sprachenwahl – Python für K.Switchboard

- **Status:** Angenommen
- **Datum:** 2025-07-17
- **Issue:** [#161](https://github.com/GrexyLoco/K.Agents/issues/161)
- **Autoren:** K.Agents-Team

---

## Kontext

K.Switchboard ist ein HTTP-Proxy, der Anfragen von KI-Tools (Claude CLI, Claude Code Extension, VS Code Copilot Chat) transparent an Anthropic oder Ollama weiterleitet. Das Projekt startete im Rahmen der K.Agents-Monorepo-Infrastruktur, die primär auf .NET, Blazor und PowerShell setzt.

Für den Switchboard-Kern musste eine Implementierungssprache gewählt werden.

### Anforderungen

| Nr. | Anforderung |
|-----|-------------|
| R1 | Asynchrone HTTP-Proxy-Funktionalität (streaming, concurrent requests) |
| R2 | Einfache JSON-Parsing- und -Serialisierungs-Pipeline |
| R3 | Low-latency Passthrough ohne merklichen Overhead |
| R4 | Einfaches Deployment ohne komplexen Build-Prozess |
| R5 | Leicht testbar (Unit + Integration) |
| R6 | Gute Bibliotheksunterstützung für HTTP-Clients und -Server |

---

## Entscheidung

**Python 3.11+** mit **FastAPI 0.115+** und **httpx** (async HTTP-Client).

---

## Alternativen

### Option A: Python (FastAPI + httpx) ✅ Gewählt

**Pro:**
- FastAPI bietet native async/await-Unterstützung mit minimalem Boilerplate
- httpx unterstützt vollständiges Streaming (SSE) mit async-Iteration
- Ausgereifte Ökosystemunterstützung für HTTP-Proxy-Muster
- Einfaches Deployment: `uv run` oder `pip install` + ein Einstiegspunkt
- `uv` als Paketmanager: reproduzierbare Environments mit `pyproject.toml`/`uv.lock`
- Niedrige Lernkurve für das Team für diesen spezifischen Use Case

**Contra:**
- Abweichend vom primären Stack (.NET/PowerShell) im Monorepo
- Typannotierungen optional (obwohl im Projekt konsequent eingesetzt)
- Python-Interpreter auf Zielmaschine erforderlich

### Option B: ASP.NET Core Minimal API (C#)

**Pro:**
- Kongruent mit dem Haupt-Stack
- Starke Typsicherheit
- Native AOT möglich (kleines Binary)

**Contra:**
- Streaming-Proxy mit `HttpClient` erheblich komplexer (`PipeWriter`, `StreamCopyTo`)
- Kein idiomatisches SSE-Streaming ohne manuelle Implementierung
- Längerer Build-Zyklus (dotnet build/publish)
- Für diesen Use Case unverhältnismäßig viel Boilerplate

### Option C: Node.js (Express / Fastify)

**Pro:**
- V8-basierte Event-Loop ideal für I/O-bound Proxies
- Gute Streaming-Unterstützung via `pipe()`

**Contra:**
- Weitere Laufzeitabhängigkeit (node + npm) neben .NET und Python
- TypeScript-Konfigurationsaufwand
- Schwächere Typsicherheit ohne aufwändiges Setup

### Option D: Go

**Pro:**
- Sehr geringe Latenz
- Einfaches Cross-Compiling zu statischen Binaries

**Contra:**
- Kein Teammitglied mit Go-Erfahrung
- Weitere Lernkurve ohne direkten Nutzengewinn gegenüber Python

---

## Konsequenzen

### Positive Konsequenzen
- Schnelle Implementierung dank FastAPI-Routing und httpx-Streaming
- `uv` ermöglicht reproduzierbare Environments ohne systemweite Python-Installation
- Pester-Tests in CI laufen parallel zu pytest ohne Konflikte

### Negative Konsequenzen / Risiken
- Das Monorepo hat jetzt zwei primäre Laufzeiten (.NET und Python). Für neue Entwickler erhöht sich die Onboarding-Last minimal.
- Python-Version muss explizit verwaltet werden (aktuell: `>=3.11`, in `pyproject.toml` festgelegt).

### Grenzen dieser Entscheidung
- Gilt nur für K.Switchboard. Alle anderen Komponenten im Monorepo (Blazor, MAUI, Minimal APIs, CI-Scripts) bleiben .NET/PowerShell.
- Diese Entscheidung kann revidiert werden, wenn der Proxy-Layer in eine eigenständige Infrastrukturkomponente mit anderen Anforderungen wächst.

---

## Einhaltung

- Python-Version: `>=3.11` (in `pyproject.toml` unter `requires-python`)
- Paketmanager: `uv` (kein pip/conda direkt in CI)
- Linting/Formatting: ruff (konfiguriert in `pyproject.toml`)
- Tests: pytest via `uv run pytest`
- Keine gemischten Sprachen innerhalb einer K.Switchboard-Komponente

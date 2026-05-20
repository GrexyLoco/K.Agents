# 1. K.Switchboard

Transparenter HTTP-Proxy, der zwischen **Claude Max Subscription** und lokalen **Ollama**-Modellen routet — ohne Änderungen am Client.

## 1.1 Was ist K.Switchboard?

K.Switchboard läuft lokal auf Port `3456` und verhält sich wie die Anthropic API. **Clients** zeigen einfach ihre API-URL auf `http://localhost:3456`:

- **Lokale Modelle** (konfigurierte Aliase wie `local-coder`) → **Provider: Ollama** (kostenlos, lokal)
- **Claude-Modelle** (z.B. `claude-sonnet-latest`) → **Provider: Anthropic API** (kostenpflichtig, transparent durchgeleitet)
- **Fallback**: Bei nicht erreichbarem Provider greift die konfigurierte [Fallback-Kette](#fallback-verhalten)

Ein **Client** ist jede Anwendung, die Anfragen im Anthropic-API-Format sendet — z.B. Claude CLI, Claude Code Extension, Continue.dev oder eigene Skripte. **Nicht kompatibel:** `claude.ai` (Web-Frontend, kein `ANTHROPIC_BASE_URL`-Support) und VS Code Copilot Chat (eigenes GitHub-Protokoll, nicht Anthropic-API).

**Providers** sind die KI-Dienste, an die K.Switchboard Anfragen weiterleitet. Aktuell werden zwei Provider unterstützt: `anthropic` (Cloud, kostenpflichtig) und `ollama` (lokal, kostenlos).

Der eigene `ANTHROPIC_API_KEY` bleibt im Client und wird bitidentisch weitergeleitet — K.Switchboard liest ihn nicht aus.

## 1.2 Installation

### 1.2.1 Windows

```powershell
# Python 3.11+ vorausgesetzt
pip install .

# Nur Konfiguration, kein Autostart
.\scripts\install-windows.ps1

# Als Scheduled Task (empfohlen — kein Admin erforderlich)
.\scripts\install-windows.ps1 -AsTask

# Als Scheduled Task mit sichtbarem Konsolenfenster (Debugging)
.\scripts\install-windows.ps1 -AsTask -Interactive

# Als Windows-Dienst (Admin erforderlich, startet beim Booten)
.\scripts\install-windows.ps1 -AsService

# Task und/oder Dienst nachträglich entfernen
.\scripts\install-windows.ps1 -Unregister
```

#### Task vs. Dienst

| | Scheduled Task | Windows Service |
|---|---|---|
| **Startet** | Bei Benutzeranmeldung | Beim Systemstart (vor Anmeldung) |
| **Kontext** | Aktueller Benutzer | SYSTEM oder Service-Account |
| **Admin erforderlich** | Nein | Ja |
| **Empfohlen für** | Einzelner Entwickler-PC | Geteilte Maschine / CI-Server |

Ein **Scheduled Task** (`-AsTask`) läuft im Kontext des angemeldeten Benutzers und hat Zugriff auf dessen Umgebungsvariablen und Netzlaufwerke. Er startet automatisch bei der nächsten Anmeldung. Ein **Windows Service** (`-AsService`) läuft unabhängig von Anmeldungen als Hintergrunddienst — erfordert jedoch Administratorrechte bei der Registrierung.

**Modus nachträglich wechseln** — keine Neuinstallation nötig:
```powershell
# 1. Bestehenden Autostart entfernen (idempotent — kein Fehler wenn nichts registriert)
.\scripts\install-windows.ps1 -Unregister

# 2. Mit gewünschtem Modus neu registrieren
.\scripts\install-windows.ps1 -AsTask    # oder -AsService
```

### 1.2.2 Linux / macOS

```bash
pip install .

# Konfigurationsverzeichnis anlegen
mkdir -p ~/.config/k-switchboard
cp config.example.yaml ~/.config/k-switchboard/config.yaml
```

## 1.3 Konfiguration

Die Konfigurationsdatei liegt unter:

| Plattform | Pfad |
|-----------|------|
| Windows | `%APPDATA%\K.Switchboard\config.yaml` |
| Linux/macOS | `~/.config/k-switchboard/config.yaml` |

```yaml
port: 3456
anthropic_base_url: https://api.anthropic.com
ollama_base_url: http://localhost:11434
```

### 1.3.1 Modell-Aliase konfigurieren

Kurzname → echter Ollama-Modellname. Modelle mit `:` werden automatisch als Ollama-Modelle erkannt.

```yaml
model_aliases:
  local-coder: codellama:13b   # Anfragen mit "local-coder" → Ollama
  local-fast:  llama3.2:3b     # Anfragen mit "local-fast"  → Ollama
```

### 1.3.2 Direkter Ollama-Zugriff ohne Alias

**Hauptpfad für VS-Code-Agents** — direkt im `.agent.md`-Frontmatter:

```yaml
---
name: My Local Agent
model: mistral:7b   # ':' im Namen → K.Switchboard routet automatisch zu Ollama
---
```

Eigene API-Clients (Python-SDK, CLI, etc.) übergeben `mistral:7b` einfach als Modellname — der Doppelpunkt sorgt automatisch für Ollama-Routing.

Vollständige Konfigurationsdokumentation: [`config.example.yaml`](config.example.yaml)

## 1.4 Client konfigurieren

K.Switchboard unterstützt jeden **Anthropic-API-kompatiblen Client**. Setze `ANTHROPIC_BASE_URL` auf `http://localhost:3456` — der `ANTHROPIC_API_KEY` bleibt unverändert im Client.

### 1.4.1 Claude CLI

```bash
# Linux / macOS — Session
export ANTHROPIC_BASE_URL=http://localhost:3456

# Linux / macOS — persistent (~/.bashrc oder ~/.zshrc)
echo 'export ANTHROPIC_BASE_URL=http://localhost:3456' >> ~/.bashrc
```

```powershell
# Windows PowerShell — Session
$env:ANTHROPIC_BASE_URL = "http://localhost:3456"

# Windows PowerShell — persistent (User-Scope)
[System.Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", "http://localhost:3456", "User")
```

### 1.4.2 Claude Code Extension (VS Code)

In der VS-Code-`settings.json` (User oder Workspace):

```json
{
  "claude.apiBaseUrl": "http://localhost:3456"
}
```

### 1.4.3 Andere Anthropic-API-kompatible Clients

Jeder Client, der `ANTHROPIC_BASE_URL` oder einen konfigurierbaren Basis-URL-Parameter unterstützt (Continue.dev, Cline, etc.), kann auf `http://localhost:3456` zeigen.

### 1.4.4 Copilot Chat (VS Code) — nicht unterstützt

VS Code Copilot Chat ist **kein Anthropic-API-Client** und lässt sich nicht über K.Switchboard routen. Copilot Chat kommuniziert direkt mit `api.githubcopilot.com` via GitHub-Token und ignoriert `ANTHROPIC_BASE_URL`. Verifikation via [Spike #162](https://github.com/GrexyLoco/K.Agents/issues/162) (ausstehend).

## 1.5 Agent-Modelle und Aliase

K.Switchboard routet anhand des `model`-Felds im Anthropic-Request-Body. Ein Alias wie `local-coder` funktioniert daher nur, wenn der Client diesen Modellnamen tatsächlich an `POST /v1/messages` sendet.

### 1.5.1 VS-Code-Agents (`.agent.md`)

Das `model`-Feld im `.agent.md`-Frontmatter ist laut [VS-Code-Dokumentation](https://code.visualstudio.com/docs/copilot/customization/custom-agents) ein einzelner Modellname oder eine priorisierte Liste. VS Code versucht das erste verfügbare Modell. Lokale Switchboard-Aliase sollten daher immer mit einem offiziell verfügbaren Fallback kombiniert werden:

```yaml
---
name: My Coding Agent
model:
  - local-coder          # Über K.Switchboard → Ollama (wenn Switchboard läuft)
  - claude-sonnet-latest  # Fallback wenn local-coder nicht verfügbar
---
```

> **Hinweis:** Nur `.agent.md`-Dateien und Handoff-Definitionen unterstützen das `model`-Feld. `.instructions.md`-Dateien, Skills und Tools haben **kein** `model`-Feld — sie erben das Modell vom aufrufenden Agent. Quelle: [VS-Code Custom Instructions Doku](https://code.visualstudio.com/docs/copilot/customization/custom-instructions).

### 1.5.2 Aliase in anderen Clients

Clients, die freie Modellnamen an die Anthropic-kompatible API senden (Claude CLI, Claude Code, eigene Skripte), werden direkt über `model_aliases` in der `config.yaml` geroutet.

Aliase sind **case-sensitiv**: `local-coder` und `local-Coder` sind unterschiedliche Modellnamen.

## 1.6 Fallback-Verhalten

Es gibt zwei unabhängige Fallback-Ebenen:

### 1.6.1 Ebene 1 — VS-Code-Modell-Picker-Fallback (vor der Request)

Wenn in `.agent.md` eine Modellliste angegeben ist, wählt VS Code **vor dem Senden der Anfrage** das erste verfügbare Modell aus dem Picker. Das ist ein Client-seitiger Mechanismus — K.Switchboard ist dabei nicht beteiligt.

```yaml
model:
  - local-coder          # VS Code prüft: ist dieses Modell verfügbar?
  - claude-sonnet-latest  # Falls nicht: nächstes in der Liste
```

### 1.6.2 Ebene 2 — Switchboard-Fallback-Kette (nach gescheiterter Request)

Wenn K.Switchboard beim Weiterleiten einen Fehler erhält (Netzwerkfehler oder HTTP 4xx/5xx vom Provider), greift die konfigurierte `fallback_chains` in der `config.yaml`:

```yaml
fallback_chains:
  - from: local-coder
    to: claude-sonnet-latest    # Ollama down → automatisch Claude

  - from: claude-sonnet-latest
    to: claude-haiku-latest     # Rate-Limit bei Sonnet → Haiku
```

Konfigurationsdatei-Pfad:

| Plattform | Pfad |
|-----------|------|
| Windows | `%APPDATA%\K.Switchboard\config.yaml` |
| Linux/macOS | `~/.config/k-switchboard/config.yaml` |

Der Client erhält den Response-Header `X-K-Switchboard-Fallback-Used: original -> fallback`, wenn der Fallback erfolgreich war. An den Provider wird dieser Header **nicht** weitergeleitet.

**Warum beide Ebenen nötig?** Ebene 1 (VS Code) fängt ab, wenn ein Modellname dem Client gänzlich unbekannt ist. Ebene 2 (Switchboard) fängt ab, wenn das Modell bekannt ist, aber der Provider zur Laufzeit nicht antwortet.

## 1.7 Deinstallation

### 1.7.1 Windows

```powershell
# 1. Autostart entfernen (Task und/oder Dienst — idempotent, kein Fehler wenn nichts registriert)
.\scripts\install-windows.ps1 -Unregister

# 2. Software deinstallieren
pip uninstall k-switchboard

# 3. Konfiguration entfernen (optional — eigene Anpassungen gehen verloren)
Remove-Item -Recurse -Force "$env:APPDATA\K.Switchboard"
```

### 1.7.2 Linux / macOS

```bash
pip uninstall k-switchboard
rm -rf ~/.config/k-switchboard
```

## 1.8 Server starten

```bash
k-switchboard
# oder
python -m k_switchboard
```

## 1.9 Endpoints

| Endpoint | Methode | Beschreibung |
|----------|---------|--------------|
| `/v1/messages` | POST | Anthropic Messages API Proxy |
| `/stats` | GET | Tages-Kosten- und Token-Statistiken |
| `/health` | GET | Health-Check (`{"status": "ok"}`) |
| `/docs` | GET | OpenAPI-Dokumentation |

## 1.10 Stats-Endpoint

```bash
curl http://localhost:3456/stats
```

```json
{
  "date": "2026-05-16",
  "models": {
    "claude-sonnet-latest": {
      "input_tokens": 45320,
      "output_tokens": 12100,
      "cost_usd": 0.317310
    },
    "local-fast": {
      "input_tokens": 8200,
      "output_tokens": 3100,
      "cost_usd": 0.0
    }
  },
  "total_cost_usd": 0.317310
}
```

Kostendaten werden täglich in `costs-YYYY-MM-DD.json` im Konfigurationsverzeichnis gespeichert.

## 1.11 Preise

> **Stand Mai 2026 — bitte vor Verwendung auf [anthropic.com/pricing](https://www.anthropic.com/pricing) prüfen.**

| Modell | Input (USD/M Tokens) | Output (USD/M Tokens) |
|--------|---------------------|-----------------------|
| claude-opus-latest | 15.00 | 75.00 |
| claude-sonnet-latest | 3.00 | 15.00 |
| claude-haiku-latest | 0.25 | 1.25 |
| Ollama (lokal) | 0.00 | 0.00 |

Die `pricing:`-Sektion in der `config.yaml` überschreibt diese Standardwerte — bei Preisänderungen einfach dort anpassen.

## 1.12 Setup verifizieren

**Wann ausführen:** nach der Installation oder bei Verbindungsproblemen.

```powershell
.\scripts\verify-setup.ps1
```

Beispiel-Output bei korrektem Setup:

```
  [OK]     K.Switchboard Health (http://localhost:3456/health)
  [OK]     Ollama Health (http://localhost:11434/api/version)

  === Tageskosten (2026-05-16) ===
  claude-sonnet-latest            In:    45320  Out:    12100  Kosten: 0.317310 USD
  local-fast                      In:     8200  Out:     3100  Kosten: 0.000000 USD
```

### 1.12.1 Troubleshooting

| Symptom | Lösung |
|---------|--------|
| `[FEHLER] K.Switchboard Health` | K.Switchboard starten: `k-switchboard` oder `python -m k_switchboard` |
| `[FEHLER] Ollama Health` | Ollama starten: `ollama serve` |
| Stats leer / `Noch keine Nutzung heute erfasst` | Noch keine Requests über Switchboard gelaufen — normaler Zustand nach Erststart |

## 1.13 Logs

| Plattform | Pfad |
|-----------|------|
| Windows | `%APPDATA%\K.Switchboard\logs\k-switchboard.log` |
| Linux/macOS | `~/.local/share/k-switchboard/logs/k-switchboard.log` |

Log-Format: JSON (Datei), Human-readable via rich (Konsole).

## 1.14 IDE-Kompatibilität

K.Switchboard ist **IDE-agnostisch** — es ist ein reiner HTTP-Proxy ohne IDE-Plugin. Es funktioniert mit jedem Client, der `ANTHROPIC_BASE_URL` berücksichtigt.

| Client / IDE | Unterstützt | Hinweis |
|---|---|---|
| Claude CLI | ✅ | `ANTHROPIC_BASE_URL` setzen |
| Claude Code Extension (VS Code) | ✅ | `claude.apiBaseUrl` in `settings.json` |
| Continue.dev | ✅ | API-Base-URL in Continue-Konfiguration |
| Cline | ✅ | `ANTHROPIC_BASE_URL` oder direkt konfigurierbar |
| Claude CLI im JetBrains-Terminal | ✅ | Wie Standard-Claude-CLI |
| VS Code Copilot Chat | ❌ | Kein Anthropic-API-Client — nutzt `api.githubcopilot.com` |
| JetBrains AI Assistant | ❌ | Proprietärer Cloud-Service, kein Anthropic-API-Client |

### 1.14.1 JetBrains / Rider

K.Switchboard lässt sich im JetBrains-Terminal mit der Claude CLI wie gewohnt nutzen. Die `plugins/kagents/`-Agents und Skills in diesem Repository sind jedoch **VS-Code-spezifisch** und funktionieren nicht in Rider — JetBrains verwendet ein eigenes, inkompatibles Agent-Customization-Modell.

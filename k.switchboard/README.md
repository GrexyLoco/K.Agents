# K.Switchboard

Transparenter HTTP-Proxy, der zwischen **Claude Max Subscription** und lokalen **Ollama**-Modellen routet — ohne Änderungen am Claude-Client.

## Was ist K.Switchboard?

K.Switchboard läuft lokal auf Port `3456` und verhält sich wie die Anthropic API. Clients zeigen einfach ihre API-URL auf `http://localhost:3456`:

- **Lokale Modelle** (konfigurierte Aliase wie `local-coder`) → Ollama
- **Claude-Modelle** (z.B. `claude-sonnet-latest`) → Anthropic API (transparent durchgeleitet)
- **Fallback**: Bei nicht erreichbarem Backend greift die konfigurierte Fallback-Kette

Der eigene Anthropic API-Key bleibt im Client und wird bitidentisch weitergeleitet.

## Installation

### Windows

```powershell
# Python 3.11+ vorausgesetzt
pip install .

# Konfiguration + optionaler Windows-Task
.\scripts\install-windows.ps1
.\scripts\install-windows.ps1 -AsTask   # automatisch bei Anmeldung starten
```

### Linux / macOS

```bash
pip install .

# Konfigurationsverzeichnis anlegen
mkdir -p ~/.config/k-switchboard
cp config.example.yaml ~/.config/k-switchboard/config.yaml
```

## Konfiguration

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

### Modell-Aliase konfigurieren

Kurzname → echter Ollama-Modellname. Modelle mit `:` werden automatisch als Ollama-Modelle erkannt.

```yaml
model_aliases:
  local-coder: codellama:13b   # Anfragen mit "local-coder" → Ollama
  local-fast:  llama3.2:3b     # Anfragen mit "local-fast"  → Ollama
```

Direkter Ollama-Zugriff ohne Alias-Konfiguration:

```python
# Direkt im Client — ':' im Namen → automatisch Ollama
client.messages.create(model="mistral:7b", ...)
```

## Claude-Client konfigurieren

```bash
# Umgebungsvariable (empfohlen)
export ANTHROPIC_BASE_URL=http://localhost:3456

# Windows PowerShell (Session)
$env:ANTHROPIC_BASE_URL = "http://localhost:3456"

# Windows PowerShell (persistent)
[System.Environment]::SetEnvironmentVariable("ANTHROPIC_BASE_URL", "http://localhost:3456", "User")
```

Der `ANTHROPIC_API_KEY` bleibt unverändert im Client — K.Switchboard leitet ihn transparent weiter.

## Agent-Modelle und Aliase

K.Switchboard routet anhand des `model`-Felds im Anthropic-Request-Body. Ein Alias wie `local-coder` funktioniert daher nur, wenn der Client diesen Modellnamen tatsächlich an `POST /v1/messages` sendet.

Für VS-Code-Agents ist das wichtig: Das `model`-Feld im `.agent.md`-Frontmatter wird von VS Code gegen verfügbare Modelle aus dem Model Picker aufgelöst. Laut offizieller VS-Code-Dokumentation darf `model` ein einzelner Modellname oder eine priorisierte Liste sein; VS Code versucht bei Listen das erste verfügbare Modell. Deshalb sollten lokale Switchboard-Aliase dort immer mit einem offiziell verfügbaren Fallback-Modell kombiniert werden:

```yaml
model:
  - local-coder
  - Claude Opus 4.6
```

Wenn `local-coder` nicht als Modell im Client verfügbar ist, nutzt VS Code den Fallback. Clients, die freie Modellnamen an die Anthropic-kompatible API senden, werden dagegen direkt über `model_aliases` geroutet. Aliase sind bewusst case-sensitiv: `local-coder` und `local-Coder` sind unterschiedliche Modellnamen.

## Fallback-Verhalten

Wenn ein Modell nicht erreichbar ist (Netzwerkfehler oder HTTP 4xx/5xx), greift die Fallback-Kette:

```yaml
fallback_chains:
  - from: local-coder
    to: claude-sonnet-latest    # Ollama down → automatisch Claude

  - from: claude-sonnet-latest
    to: claude-haiku-latest     # Rate-Limit bei Sonnet → Haiku
```

Der Client erhält den Header `X-K-Switchboard-Fallback-Used: original -> fallback`, wenn der Fallback erfolgreich war. Ans Backend wird dieser Header **nicht** weitergeleitet.

## Server starten

```bash
k-switchboard
# oder
python -m k_switchboard
```

## Endpoints

| Endpoint | Methode | Beschreibung |
|----------|---------|--------------|
| `/v1/messages` | POST | Anthropic Messages API Proxy |
| `/stats` | GET | Tages-Kosten- und Token-Statistiken |
| `/health` | GET | Health-Check (`{"status": "ok"}`) |
| `/docs` | GET | OpenAPI-Dokumentation |

## Stats-Endpoint

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

## Preise (Stand Mai 2026)

| Modell | Input (USD/M Tokens) | Output (USD/M Tokens) |
|--------|---------------------|-----------------------|
| claude-opus-latest | 15.00 | 75.00 |
| claude-sonnet-latest | 3.00 | 15.00 |
| claude-haiku-latest | 0.25 | 1.25 |
| Ollama (lokal) | 0.00 | 0.00 |

## Setup verifizieren

```powershell
.\scripts\verify-setup.ps1
```

## Logs

| Plattform | Pfad |
|-----------|------|
| Windows | `%APPDATA%\K.Switchboard\logs\k-switchboard.log` |
| Linux/macOS | `~/.local/share/k-switchboard/logs/k-switchboard.log` |

Log-Format: JSON (Datei), Human-readable via rich (Konsole).

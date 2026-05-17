# Migration von Python nach .NET

Diese Seite zeigt den direkten Vergleich zwischen dem Python-basierten K.Switchboard (`k.switchboard/`) und der .NET-Version (`k.switchboard.net/`).

---

## Befehle im Vergleich

| Aktion | Python | .NET |
|--------|--------|------|
| **Starten (Vordergrund)** | `python -m k_switchboard` | `.\K.Switchboard.exe` |
| **Als Service installieren** | `.\install-windows.ps1 -AsService` (pywin32) | `.\scripts\install-windows.ps1 -AsService` (sc.exe) |
| **Als Task registrieren** | `.\install-windows.ps1 -AsTask` | *(nicht unterstützt — Service-Modus bevorzugt)* |
| **Deinstallieren** | `.\install-windows.ps1 -Unregister` | `.\scripts\install-windows.ps1 -Unregister` |
| **Service starten** | `Start-Service KSwitchboard` | `Start-Service K.Switchboard` |
| **Service stoppen** | `Stop-Service KSwitchboard` | `Stop-Service K.Switchboard` |
| **Service-Status** | `Get-Service KSwitchboard` | `Get-Service K.Switchboard` |
| **Health-Check** | `Invoke-RestMethod http://localhost:3456/health` | `Invoke-RestMethod http://localhost:3456/health` |
| **Statistiken** | *(nicht vorhanden)* | `Invoke-RestMethod http://localhost:3456/stats` |
| **Runtime-Abhängigkeit** | Python 3.11+ erforderlich | Keine — Self-Contained EXE |

---

## Konfiguration: YAML → JSON

Die Python-Version verwendet YAML (`config.yaml`), die .NET-Version JSON (`config.json`). Die Struktur ist weitgehend identisch.

| YAML-Feld | JSON-Feld | Hinweis |
|-----------|-----------|---------|
| `port` | `Port` | Gleicher Standardwert: 3456 |
| `anthropic_base_url` | `AnthropicBaseUrl` | Gleicher Standardwert |
| `ollama_base_url` | `OllamaBaseUrl` | Gleicher Standardwert |
| `model_aliases` | `ModelAliases` | Gleiche Semantik, camelCase→PascalCase |
| `fallback_chains` | `FallbackChains` | YAML: Liste von `{from, to}` → JSON: Dictionary `{primary: [fallbacks]}` |
| `pricing` | `Pricing` | YAML: `input_per_million` → JSON: `InputPerMillion` |

### Beispiel

**Python (YAML):**

```yaml
port: 3456
anthropic_base_url: https://api.anthropic.com
ollama_base_url: http://localhost:11434
model_aliases:
  local-coder: codellama:13b
fallback_chains:
  - from: claude-opus-latest
    to: claude-sonnet-latest
pricing:
  claude-3-5-sonnet-20241022:
    input_per_million: 3.0
    output_per_million: 15.0
```

**.NET (JSON):**

```json
{
  "Port": 3456,
  "AnthropicBaseUrl": "https://api.anthropic.com",
  "OllamaBaseUrl": "http://localhost:11434",
  "ModelAliases": {
    "local-coder": "codellama:13b"
  },
  "FallbackChains": {
    "claude-opus-latest": ["claude-sonnet-latest"]
  },
  "Pricing": {
    "claude-3-5-sonnet-20241022": {
      "InputPerMillion": 3.0,
      "OutputPerMillion": 15.0
    }
  }
}
```

---

## Unterschiede und neue Features

| Aspekt | Python | .NET |
|--------|--------|------|
| **Service-Name** | `KSwitchboard` | `K.Switchboard` |
| **Log-Format** | strukturiert (Python logging) | Serilog strukturiert + File-Sink |
| **OpenTelemetry** | nicht vorhanden | integriert, opt-in via OTLP |
| **Tagesstatistiken** | nicht vorhanden | `/stats`-Endpoint |
| **Fallback-Header** | nicht vorhanden | `X-K-Switchboard-Fallback-Used` |
| **Hot-Reload Config** | nicht vorhanden | automatisch via IOptionsMonitor |
| **Runtime** | Python 3.11+ + pip | keine (self-contained) |
| **Dateigröße** | ~5 MB (Python + Deps) | ~21 MB (single-file EXE) |

---

## Konfigurationspfade

| Aspekt | Python | .NET |
|--------|--------|------|
| **Konfig-Datei** | `%APPDATA%\K.Switchboard\config.yaml` | `%APPDATA%\K.Switchboard\config.json` |
| **Log-Dateien** | *(in Python konfigurierbar)* | `%APPDATA%\K.Switchboard\logs\k.switchboard-YYYYMMDD.log` |
| **Statistik-Dateien** | nicht vorhanden | `%APPDATA%\K.Switchboard\costs-yyyy-MM-dd.json` |
| **EXE-Installationsort** | `%LOCALAPPDATA%\K.Switchboard\` (per Installer) | `%LOCALAPPDATA%\K.Switchboard\` (per Installer) |

---

## Parallelbetrieb

Beide Versionen (`k.switchboard/` und `k.switchboard.net/`) können parallel betrieben werden, sofern sie auf unterschiedlichen Ports laufen. Die .NET-Version liest ihre eigene `config.json` — die Python-`config.yaml` bleibt davon unberührt.

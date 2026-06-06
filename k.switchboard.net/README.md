# 1. K.Switchboard .NET

<!-- markdownlint-disable MD033 -->

K.Switchboard ist ein leichtgewichtiger KI-Proxy für [Anthropic](https://docs.anthropic.com/en/api/messages)- und [Ollama](https://github.com/ollama/ollama/blob/main/docs/api.md)-Backends. Er nimmt Anfragen im Anthropic-API-Format entgegen und leitet sie je nach Modellname an den passenden Provider weiter.

**Stack:** .NET 10 · ASP.NET Core Minimal API · Single-File-EXE · Windows Service

---

## 1.1 Inhaltsverzeichnis

- [Beziehen](#usage-beziehen)
- [Installieren](#usage-installieren)
- [Konfigurieren](#usage-konfigurieren)
- [Ausführen](#usage-ausfuehren)
- [Monitoren](#usage-monitoren)
- [Deinstallieren](#usage-deinstallieren)
- [Python-Befehl → .NET-Befehl](#python-dotnet-commands)
- [Weiteres](#weiteres)

---

<a id="usage-beziehen"></a>

## 1.2 Beziehen

K.Switchboard wird als Release-Bundle über [GitHub Releases](https://github.com/GrexyLoco/K.Agents/releases/latest) bereitgestellt. Das ZIP enthält `K.Switchboard.exe`, `install-windows.ps1` und `K.Switchboard-README.md`. Es ist keine .NET-Runtime-Installation erforderlich — die EXE ist self-contained ([Self-contained deployment](https://learn.microsoft.com/en-us/dotnet/core/deploying/#publish-self-contained)).

**Browser-Download:** Öffne `https://github.com/GrexyLoco/K.Agents/releases/latest`, lade das Asset `K.Switchboard-win-x64.zip` herunter (optional zusätzlich `K.Switchboard-README.md` als separates Asset).

**CLI-Download** mit [GitHub CLI](https://cli.github.com/manual/gh_release_download):

```pwsh
gh release download --repo GrexyLoco/K.Agents --pattern "K.Switchboard-win-x64.zip" --pattern "K.Switchboard-README.md" --dir "$env:LOCALAPPDATA\K.Switchboard"
```

**Entpacken:**

```pwsh
$dest = "$env:LOCALAPPDATA\K.Switchboard"
New-Item -ItemType Directory -Path $dest -Force | Out-Null
Expand-Archive -Path (Join-Path $dest 'K.Switchboard-win-x64.zip') -DestinationPath $dest -Force
```

---

<a id="usage-installieren"></a>

## 1.3 Installieren

Es gibt zwei Modi: **portabel** (EXE liegt in einem Ordner) und **Windows-Service** (automatischer Start, kein Login nötig).

### 1.3.1 Portabel

Nach dem Entpacken kann die EXE direkt gestartet werden, z. B. aus `%LOCALAPPDATA%\K.Switchboard\`:

```pwsh
& "$env:LOCALAPPDATA\K.Switchboard\K.Switchboard.exe"
```

### 1.3.2 Windows-Service

Verwende das mitgelieferte PowerShell-Installer-Skript `install-windows.ps1` aus dem Bundle. Es nutzt [`sc.exe`](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/sc-create) und benötigt **Administratorrechte**.

```pwsh
# Skript im entpackten Bundle-Verzeichnis ausführen:
.\install-windows.ps1 -AsService -ExePath "$env:LOCALAPPDATA\K.Switchboard\K.Switchboard.exe"
```

Der Service heißt `K.Switchboard`, läuft unter `NT AUTHORITY\NetworkService` und startet automatisch verzögert (`Automatic Delayed`). Intern basiert der Service-Host auf [`Microsoft.Extensions.Hosting.WindowsServices`](https://learn.microsoft.com/en-us/dotnet/core/extensions/windows-service).

---

<a id="usage-konfigurieren"></a>

## 1.4 Konfigurieren

Beim ersten Start legt K.Switchboard eine Default-Konfiguration unter `%APPDATA%\K.Switchboard\config.json` an. Diese Datei kann mit jedem Texteditor bearbeitet werden. Änderungen werden zur Laufzeit automatisch erkannt ([IOptionsMonitor Hot-Reload](https://learn.microsoft.com/en-us/dotnet/core/extensions/options#use-ioptionsmonitor-to-read-updated-data)) — kein Neustart nötig.

**Minimale Konfiguration:**

```json
{
  "Port": 3456,
  "AnthropicBaseUrl": "https://api.anthropic.com",
  "OllamaBaseUrl": "http://localhost:11434",
  "ModelAliases": {
    "local-coder": "codellama:13b",
    "local-fast": "llama3.2:3b"
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

Das vollständige Schema mit allen Feldern und Standardwerten ist in [docs/configuration.md](docs/configuration.md) dokumentiert.

---

<a id="usage-ausfuehren"></a>

## 1.5 Ausführen

### 1.5.1 Portabel / Vordergrund

```pwsh
& "$env:LOCALAPPDATA\K.Switchboard\K.Switchboard.exe"
```

Die EXE bindet sich auf den konfigurierten Port (Standard: 3456) und gibt Logs auf stdout aus.

### 1.5.2 Als Windows-Service

```pwsh
Start-Service K.Switchboard
```

Status prüfen mit [`Get-Service`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-service):

```pwsh
Get-Service K.Switchboard
```

**Anthropic-Clients eintragen:** Setze die Umgebungsvariable `ANTHROPIC_BASE_URL=http://localhost:3456`. Damit gehen alle Anthropic-API-Aufrufe durch den Proxy. Claude Code, Copilot und andere Clients lesen diese Variable automatisch aus.

---

<a id="usage-monitoren"></a>

## 1.6 Monitoren

K.Switchboard stellt mehrere Beobachtungsflächen bereit. Details stehen in [docs/monitoring.md](docs/monitoring.md).

### 1.6.1 Health-Check

```pwsh
Invoke-RestMethod http://localhost:3456/health
# Erwartete Antwort: Healthy
```

Implementiert über [`Microsoft.Extensions.Diagnostics.HealthChecks`](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks).

### 1.6.2 Tagesstatistik (Token-Kosten)

```pwsh
Invoke-RestMethod http://localhost:3456/stats
```

Liefert Token-Counts und USD-Kosten pro Modell für den aktuellen UTC-Tag. Konfiguration der Preise in `config.json` unter `Pricing` — Schema in [docs/configuration.md](docs/configuration.md).

### 1.6.3 Logs

- **Konsole** im Vordergrundmodus: strukturiertes Serilog-Format.
- **Datei** im Service-Modus: `%APPDATA%\K.Switchboard\logs\k.switchboard-YYYYMMDD.log` ([Serilog File Sink](https://github.com/serilog/serilog-sinks-file)).
- **OpenTelemetry**: aktivierbar über `OTEL_EXPORTER_OTLP_ENDPOINT` — [OpenTelemetry Spec](https://opentelemetry.io/docs/specs/otel/protocol/exporter/).

---

<a id="usage-deinstallieren"></a>

## 1.7 Deinstallieren

### 1.7.1 Service entfernen

```pwsh
.\install-windows.ps1 -Unregister
```

Das Skript stoppt den Service und ruft [`sc.exe delete`](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/sc-delete) auf.

### 1.7.2 Dateien und Konfiguration entfernen

```pwsh
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\K.Switchboard"
Remove-Item -Recurse -Force "$env:APPDATA\K.Switchboard"
Remove-Item -Recurse -Force "$env:ProgramData\K.Switchboard"
```

**Anthropic-Clients zurückstellen:** `ANTHROPIC_BASE_URL`-Variable entfernen oder auf `https://api.anthropic.com` setzen.

---

<a id="python-dotnet-commands"></a>

## 1.8 Python-Befehl → .NET-Befehl

Die häufigsten Betriebsbefehle aus der Python-Version und das direkte .NET-Pendant:

| Aktion | Python | .NET |
| -------- | -------- | ------ |
| Starten (Vordergrund) | `python -m k_switchboard` | `./K.Switchboard.exe` |
| Als Service installieren | `./install-windows.ps1 -AsService` | `./install-windows.ps1 -AsService` |
| Deinstallieren | `./install-windows.ps1 -Unregister` | `./install-windows.ps1 -Unregister` |
| Service starten | `Start-Service KSwitchboard` | `Start-Service K.Switchboard` |
| Service stoppen | `Stop-Service KSwitchboard` | `Stop-Service K.Switchboard` |
| Health-Check | `Invoke-RestMethod http://localhost:3456/health` | `Invoke-RestMethod http://localhost:3456/health` |

Die vollständige Migrationstabelle inklusive YAML→JSON-Mapping steht in [docs/migration-from-python.md](docs/migration-from-python.md).

---

<a id="weiteres"></a>

## 1.9 Weiteres

- [Konfigurationsreferenz](docs/configuration.md) — vollständiges JSON-Schema
- [Monitoring](docs/monitoring.md) — Logs, OpenTelemetry, Aspire Dashboard
- [Troubleshooting](docs/troubleshooting.md) — Symptome, Ursachen, Lösungen
- [Migration von Python](docs/migration-from-python.md) — Befehlsvergleich und Config-Mapping
- [RFC-178 Erfüllungsnachweis](docs/rfc-178-fulfillment.md) — checklistenbasierter Nachweisstand
- [RFC-177 Auslieferungsstrategie](docs/rfc-177-delivery-strategy.md) — Optionenvergleich (Release-ZIP, Docker, winget) inkl. lokale-KI-Frage

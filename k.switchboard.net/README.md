# K.Switchboard .NET

K.Switchboard ist ein leichtgewichtiger KI-Proxy für [Anthropic](https://docs.anthropic.com/en/api/messages)- und [Ollama](https://github.com/ollama/ollama/blob/main/docs/api.md)-Backends. Er nimmt Anfragen im Anthropic-API-Format entgegen und leitet sie je nach Modellname an den passenden Provider weiter.

**Stack:** .NET 10 · ASP.NET Core Minimal API · Single-File-EXE · Windows Service

---

## Inhaltsverzeichnis

- [Beziehen](#beziehen)
- [Installieren](#installieren)
- [Konfigurieren](#konfigurieren)
- [Ausführen](#ausfuhren)
- [Monitoren](#monitoren)
- [Deinstallieren](#deinstallieren)
- [Weiteres](#weiteres)

---

## Beziehen

K.Switchboard wird als Single-File-EXE über [GitHub Releases](https://github.com/GrexyLoco/K.Agents/releases/latest) bereitgestellt. Es ist keine .NET-Runtime-Installation erforderlich — die EXE enthält alles ([Self-contained deployment](https://learn.microsoft.com/en-us/dotnet/core/deploying/#publish-self-contained)).

**Browser-Download:** Öffne `https://github.com/GrexyLoco/K.Agents/releases/latest`, lade das Asset `K.Switchboard.exe` herunter.

**CLI-Download** mit [GitHub CLI](https://cli.github.com/manual/gh_release_download):

```pwsh
gh release download --repo GrexyLoco/K.Agents --pattern "K.Switchboard.exe" --dir "$env:LOCALAPPDATA\K.Switchboard"
```

---

## Installieren

Es gibt zwei Modi: **portabel** (EXE liegt in einem Ordner) und **Windows-Service** (automatischer Start, kein Login nötig).

### Portabel

Verschiebe die EXE in ein Verzeichnis deiner Wahl, z. B. `%LOCALAPPDATA%\K.Switchboard\`:

```pwsh
$dest = "$env:LOCALAPPDATA\K.Switchboard"
New-Item -ItemType Directory -Path $dest -Force | Out-Null
Move-Item .\K.Switchboard.exe $dest -Force
```

### Windows-Service

Verwende das mitgelieferte PowerShell-Installer-Skript `scripts\install-windows.ps1`. Es nutzt [`sc.exe`](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/sc-create) und benötigt **Administratorrechte**.

```pwsh
# Skript aus dem Repo-Verzeichnis ausführen (oder EXE-Pfad explizit angeben):
.\scripts\install-windows.ps1 -AsService -ExePath "$env:LOCALAPPDATA\K.Switchboard\K.Switchboard.exe"
```

Der Service heißt `K.Switchboard`, läuft unter `NT AUTHORITY\NetworkService` und startet automatisch verzögert (`Automatic Delayed`). Intern basiert der Service-Host auf [`Microsoft.Extensions.Hosting.WindowsServices`](https://learn.microsoft.com/en-us/dotnet/core/extensions/windows-service).

---

## Konfigurieren

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

## Ausführen

### Portabel / Vordergrund

```pwsh
& "$env:LOCALAPPDATA\K.Switchboard\K.Switchboard.exe"
```

Die EXE bindet sich auf den konfigurierten Port (Standard: 3456) und gibt Logs auf stdout aus.

### Als Windows-Service

```pwsh
Start-Service K.Switchboard
```

Status prüfen mit [`Get-Service`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/get-service):

```pwsh
Get-Service K.Switchboard
```

**Anthropic-Clients eintragen:** Setze die Umgebungsvariable `ANTHROPIC_BASE_URL=http://localhost:3456`. Damit gehen alle Anthropic-API-Aufrufe durch den Proxy. Claude Code, Copilot und andere Clients lesen diese Variable automatisch aus.

---

## Monitoren

K.Switchboard stellt mehrere Beobachtungsflächen bereit. Details stehen in [docs/monitoring.md](docs/monitoring.md).

### Health-Check

```pwsh
Invoke-RestMethod http://localhost:3456/health
# Erwartete Antwort: Healthy
```

Implementiert über [`Microsoft.Extensions.Diagnostics.HealthChecks`](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks).

### Tagesstatistik (Token-Kosten)

```pwsh
Invoke-RestMethod http://localhost:3456/stats
```

Liefert Token-Counts und USD-Kosten pro Modell für den aktuellen UTC-Tag. Konfiguration der Preise in `config.json` unter `Pricing` — Schema in [docs/configuration.md](docs/configuration.md).

### Logs

- **Konsole** im Vordergrundmodus: strukturiertes Serilog-Format.
- **Datei** im Service-Modus: `%APPDATA%\K.Switchboard\logs\k.switchboard-YYYYMMDD.log` ([Serilog File Sink](https://github.com/serilog/serilog-sinks-file)).
- **OpenTelemetry**: aktivierbar über `OTEL_EXPORTER_OTLP_ENDPOINT` — [OpenTelemetry Spec](https://opentelemetry.io/docs/specs/otel/protocol/exporter/).

---

## Deinstallieren

### Service entfernen

```pwsh
.\scripts\install-windows.ps1 -Unregister
```

Das Skript stoppt den Service und ruft [`sc.exe delete`](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/sc-delete) auf.

### Dateien und Konfiguration entfernen

```pwsh
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\K.Switchboard"
Remove-Item -Recurse -Force "$env:APPDATA\K.Switchboard"
Remove-Item -Recurse -Force "$env:ProgramData\K.Switchboard"
```

**Anthropic-Clients zurückstellen:** `ANTHROPIC_BASE_URL`-Variable entfernen oder auf `https://api.anthropic.com` setzen.

---

## Weiteres

- [Konfigurationsreferenz](docs/configuration.md) — vollständiges JSON-Schema
- [Monitoring](docs/monitoring.md) — Logs, OpenTelemetry, Aspire Dashboard
- [Troubleshooting](docs/troubleshooting.md) — Symptome, Ursachen, Lösungen
- [Migration von Python](docs/migration-from-python.md) — Befehlsvergleich und Config-Mapping

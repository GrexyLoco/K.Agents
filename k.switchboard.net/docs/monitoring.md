# Monitoring

<!-- markdownlint-disable MD033 -->

K.Switchboard stellt drei Beobachtungsebenen bereit: Health-Checks, strukturierte Logs und OpenTelemetry-Traces/Metriken.

---

<a id="health-checks"></a>

## Health-Checks

Der Health-Check-Endpoint gibt den Betriebszustand der Anwendung zurück. Implementiert über [`Microsoft.Extensions.Diagnostics.HealthChecks`](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/health-checks).

```pwsh
Invoke-RestMethod http://localhost:3456/health
# Antwort: Healthy
```

**HTTP-Statuscodes:**

| Status | Code | Bedeutung |
| ------ | ---- | --------- |
| `Healthy` | 200 | Anwendung läuft normal |
| `Degraded` | 200 | Anwendung läuft, aber mit Einschränkungen |
| `Unhealthy` | 503 | Anwendung nicht betriebsbereit |

Der Endpoint eignet sich für Monitoring-Tools, Load-Balancer-Probes und Windows-Service-Watchdogs.

---

<a id="logs"></a>

## Logs

K.Switchboard verwendet [Serilog](https://serilog.net/) für strukturiertes Logging.

### Konsolenmodus

Im Vordergrundmodus (direkte EXE-Ausführung) erscheinen Logs im Format:

```text
[15:02:27 INF] [K.Switchboard.Services.FallbackService] Anfrage an Modell claude-3-5-sonnet
[15:02:28 INF] [K.Switchboard.Services.CostingService] Nutzung erfasst: Modell=claude-3-5-sonnet-20241022, Input=1024, Output=256, Kosten=0.006960 USD
```

### Datei-Sink (Service-Modus)

Im Windows-Service-Modus werden Logs in tägliche Dateien geschrieben ([Serilog File Sink](https://github.com/serilog/serilog-sinks-file)):

```text
%APPDATA%\K.Switchboard\logs\k.switchboard-20260517.log
```

Log-Dateien werden 7 Tage aufbewahrt (`retainedFileCountLimit: 7`). Ältere Dateien werden automatisch gelöscht.

### Log-Level konfigurieren

Das Log-Level lässt sich in `config.json` unter dem `Serilog`-Abschnitt überschreiben:

```json
{
  "Serilog": {
    "MinimumLevel": {
      "Default": "Information",
      "Override": {
        "Microsoft": "Warning",
        "System": "Warning"
      }
    }
  }
}
```

Unterstützte Level: `Verbose`, `Debug`, `Information`, `Warning`, `Error`, `Fatal`.

---

<a id="opentelemetry"></a>

## OpenTelemetry

K.Switchboard ist mit dem [OpenTelemetry .NET SDK](https://opentelemetry.io/docs/languages/net/) instrumentiert. Im Standardbetrieb ist der OTLP-Exporter deaktiviert.

### Aktivierung

Setze die Umgebungsvariable `OTEL_EXPORTER_OTLP_ENDPOINT` auf den OTLP-Endpunkt deines Collectors:

```pwsh
$env:OTEL_EXPORTER_OTLP_ENDPOINT = "http://localhost:4317"
& "$env:LOCALAPPDATA\K.Switchboard\K.Switchboard.exe"
```

**Spezifikation:** [OpenTelemetry Environment Variable Specification](https://opentelemetry.io/docs/specs/otel/protocol/exporter/)

### Aspire Dashboard (lokal)

Das [.NET Aspire Dashboard](https://learn.microsoft.com/en-us/dotnet/aspire/fundamentals/dashboard/overview) kann im Standalone-Modus ohne AppHost betrieben werden:

```pwsh
# Aspire Dashboard als Container starten:
docker run --rm -p 18888:18888 -p 4317:18889 mcr.microsoft.com/dotnet/aspire-dashboard:latest

# K.Switchboard mit OTLP verbinden:
$env:OTEL_EXPORTER_OTLP_ENDPOINT = "http://localhost:4317"
& "$env:LOCALAPPDATA\K.Switchboard\K.Switchboard.exe"
```

Dashboard öffnen: `http://localhost:18888`

---

<a id="stats-endpoint"></a>

## Tagesstatistik (/stats)

Der `/stats`-Endpoint liefert Token-Verbrauch und USD-Kosten für den aktuellen UTC-Tag:

```pwsh
Invoke-RestMethod http://localhost:3456/stats
```

**Beispielantwort:**

```json
{
  "date": "2026-05-17",
  "models": {
    "claude-3-5-sonnet-20241022": {
      "inputTokens": 45200,
      "outputTokens": 8900,
      "costUsd": 0.268300
    }
  },
  "totalCostUsd": 0.268300
}
```

Statistiken werden in `%APPDATA%\K.Switchboard\costs-yyyy-MM-dd.json` gespeichert. Preise müssen in `config.json` unter `Pricing` konfiguriert sein — siehe [Konfigurationsreferenz](configuration.md#pricing).

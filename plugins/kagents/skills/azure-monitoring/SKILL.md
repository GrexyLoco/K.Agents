---
name: azure-monitoring
description: "Azure Monitor, Application Insights, OpenTelemetry — metrics, traces, logs, custom Meter/Counter/Histogram, SLO-based alerts, Aspire Dashboard. USE FOR: configuring monitoring pipelines, creating alert rules, instrumenting .NET services with OpenTelemetry. DO NOT USE FOR: Aspire AppHost configuration (use aspire-architecture) or general Azure resource provisioning (use azure-specialist agent)."
---

# 1. Azure Monitoring & OpenTelemetry

## 1.1 OpenTelemetry Setup (.NET)
```csharp
builder.Services.AddOpenTelemetry()
    .ConfigureResource(r => r.AddService("MyApp"))
    .WithTracing(t => t
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddEntityFrameworkCoreInstrumentation()
        .AddOtlpExporter())
    .WithMetrics(m => m
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddOtlpExporter());
```

## 1.2 Application Insights
```csharp
// Connection String (nicht Instrumentation Key!)
builder.Services.AddApplicationInsightsTelemetry(options =>
{
    options.ConnectionString = builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"];
});
```

## 1.3 Umgebungsvariablen
| Variable | Lokal (Aspire) | Produktion (Azure) |
|----------|---------------|-------------------|
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://localhost:4317` | — |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | — | `InstrumentationKey=...` |
| `OTEL_SERVICE_NAME` | Auto (Aspire) | Manuell setzen |

## 1.4 Custom Metrics
```csharp
private static readonly Meter AppMeter = new("MyApp.Business");
private static readonly Counter<long> OrdersCreated = AppMeter.CreateCounter<long>("orders.created");
private static readonly Histogram<double> OrderProcessingTime = AppMeter.CreateHistogram<double>("orders.processing_time_ms");
```

## 1.5 Alert-Design
- SLO-basiert: „99.9% der Requests unter 500ms" statt „CPU > 80%"
- Severity korrekt: Sev0 = Ausfall, Sev1 = Degradation, Sev2 = Warning
- Action Groups: Teams-Channel für Sev0/1, Email für Sev2
- Alert-Fatigue vermeiden: Aggregation, Suppression Windows

---
name: aspire-architecture
description: ".NET Aspire AppHost, Service Defaults, integrations (Postgres, Redis), service discovery, health checks, Polly resilience, telemetry pipeline. USE FOR: configuring Aspire orchestration, adding service references, setting up cloud-native distributed applications. DO NOT USE FOR: Aspire integration tests (use aspire-integration-testing) or Azure Monitor alerts (use azure-monitoring)."
---

# 1. .NET Aspire Architecture

## 1.1 AppHost-Konfiguration
```csharp
var builder = DistributedApplication.CreateBuilder(args);

var postgres = builder.AddPostgres("postgres")
    .WithPgAdmin()
    .AddDatabase("appdb");

var redis = builder.AddRedis("cache");

var api = builder.AddProject<Projects.MyApp_Api>("api")
    .WithReference(postgres)
    .WithReference(redis)
    .WithExternalHttpEndpoints();

builder.AddProject<Projects.MyApp_Web>("web")
    .WithReference(api)
    .WaitFor(api);

builder.Build().Run();
```

## 1.2 Service Defaults
```csharp
public static IHostApplicationBuilder AddServiceDefaults(this IHostApplicationBuilder builder)
{
    builder.ConfigureOpenTelemetry();
    builder.AddDefaultHealthChecks();
    builder.Services.AddServiceDiscovery();
    builder.Services.ConfigureHttpClientDefaults(http =>
    {
        http.AddStandardResilienceHandler();
        http.AddServiceDiscovery();
    });
    return builder;
}
```

## 1.3 Telemetry-Pipeline
- **Lokal:** OTLP → Aspire Dashboard (localhost:18888)
- **Produktion:** OTLP → Azure Monitor / Application Insights
- **EU-Alternative:** OTLP → Grafana Cloud (EU) / Self-hosted Collector

## 1.4 Regeln
- Service Discovery über Aspire, nicht hardcoded URLs
- Health Checks für jeden Service registrieren
- Resilience mit Polly (über `AddStandardResilienceHandler`)
- Umgebungsvariablen: `OTEL_EXPORTER_OTLP_ENDPOINT`, `APPLICATIONINSIGHTS_CONNECTION_STRING`

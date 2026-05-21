---
name: solution-layer-design
description: "Solution-Layer-Design — Domain/App/Infra/Presentation Schichten, Aspire AppHost, Modular-Monolith-Entscheidungen. USE FOR: designing layered architecture, deciding when to use monolith vs. services, structuring Aspire orchestration. DO NOT USE FOR: Minimal API implementation (use minimal-api-patterns) or Aspire integration tests (use aspire-integration-testing)."
---

# 1. Solution-Layer-Design

## 1.1 Vier-Schichten-Architektur

**Domain Layer** (Business Logic)
- Entities, Value Objects, Aggregates
- Domain Services (keine Infrastructure-Abhängigkeiten)
- Exceptions und Specifications
- Rule engine, validation rules

**Application Layer** (Use Cases)
- Application Services (Orchstrierung von Domain)
- DTOs für externe Contracts
- Validation Pipelines (FluentValidation, etc.)
- Event Publishing

**Infrastructure Layer** (Data & External)
- Repository Implementations
- EF Core DbContext, Migrations
- External Service Integrations (Azure, APIs)
- Background Jobs, Caching, Logging

**Presentation Layer** (API/UI)
- Controllers / Minimal API Endpoints
- Request/Response Records
- Authorization Policies
- OpenAPI Generation

## 1.2 Aspire AppHost Design

```csharp
var builder = DistributedApplication.CreateBuilder(args);

// Data Services
var postgres = builder.AddPostgres("postgres")
    .AddDatabase("maindb");
var redis = builder.AddRedis("cache");

// API Service
var api = builder.AddProject<Projects.MyApp_Api>("api")
    .WithReference(postgres)
    .WithReference(redis)
    .WithExternalHttpEndpoints();

// Background Worker
builder.AddProject<Projects.MyApp_Worker>("worker")
    .WithReference(postgres)
    .WaitFor(api);

// Presentation Layer
builder.AddProject<Projects.MyApp_Web>("web")
    .WithReference(api)
    .WaitFor(api);

builder.Build().Run();
```

**Pattern:** Services referenzieren abhängige Infrastruktur; Abhängigkeiten top-down (Web → API → DB/Cache).

## 1.3 Monolith vs. Microservices

| Entscheidung | Monolith | Services |
|---|---|---|
| Komplexität | Domain relativ unabhängig | Multiple Bounded Contexts |
| Deployment | Single Artifact | Separate Releases |
| Data | Shared DB oder logisch getrennt | DB pro Service (optional) |
| Communication | In-Process | HTTP/gRPC/Messaging |
| Team Scaling | <3-4 Teams schwierig | Multiple autonomous teams |

**Modular Monolith:** Physisch single Deployment, aber logisch getrennte Module mit feinen Schnittstellen.

## 1.4 Abhängigkeits-Regeln

- Domain hat **keine** Abhängigkeiten zu anderen Layern
- Application kennt Infrastructure über Interfaces (Dependency Inversion)
- Presentation konsumiert Application Services
- Circular Dependencies: **verboten**

Prüfe mit Architecture Tests (ArchUnit, NetArchTest).


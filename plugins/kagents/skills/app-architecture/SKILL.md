---
name: app-architecture
description: .NET Applikationsarchitektur — Modular Monolith, Microservices, Clean Architecture für Blazor, MAUI, ASP.NET Core
---

# 1. App-Architecture Skill

## 1.1 Übersicht

Dieses Skill führt durch fundierte Architekturentscheidungen für .NET-Projekte. Es behandelt Modular Monolith vs. Microservices, Layer-Struktur, Blazor-Render-Modes und MAUI-MVVM Patterns.

## 1.2 Solution-Struktur Design

### 1.2.1 Layer-Trennung
- **Domain Layer:** Business-Logik, Entities, Value Objects
- **Application Layer:** Use Cases, DTOs, Service-Interfaces
- **Infrastructure Layer:** EF Core, Repositories, externe Integrationen
- **Presentation Layer:** Blazor Components, Controllers, API-Endpoints
- **Shared Layer:** Cross-Cutting Concerns, Extensions, Utilities

### 1.2.2 Projekt-Abhängigkeiten
```
Presentation → Application → Domain
Infrastructure → (Domain, Application)
Shared → (alle Layer)
```

### 1.2.3 Aspire AppHost
- Orchestrierungsprojekt für Entwicklung und Deployment
- ServiceDefaults für gemeinsame Konfiguration
- Integrations für externe Services (Databases, Message Queues, Caches)

## 1.3 Architekturmuster

### 1.3.1 Modular Monolith empfehlen wenn:
- Team < 10 Entwickler
- Einzelne Deployment-Einheit
- Module haben klare Bounded Contexts
- Gemeinsame Datenbank akzeptabel
- Priorität: Einfachheit und Velocity

### 1.3.2 Microservices empfehlen wenn:
- Unabhängiges Deployment erforderlich
- Unterschiedliche Skalierungsanforderungen
- Verschiedene Tech-Stacks pro Service
- Team groß genug für Service-Ownership
- High-Availability Anforderungen

## 1.4 Blazor-Architekturentscheidungen

### 1.4.1 Render Modes (.NET 10)
| Mode | Einsatz | Latenzen | SEO | Offline |
|------|---------|----------|-----|---------|
| **Static SSR** | Content-schwere Sites | Niedrig | Ja | Nein |
| **Interactive Server** | Echtzeit-UI mit Server-State | Mittel | Nein | Nein |
| **Interactive WASM** | Desktop-ähnliche Apps | Hoch initial | Nein | Ja |
| **Auto** | Hybrid — WASM mit Server-Fallback | Mittel | Nein | Teilweise |

### 1.4.2 State Management
- **Cascading Values:** Einfache Parameter-Übergabe
- **Fluxor:** Redux-ähnlicher State für komplexe Szenarien
- **Custom Services:** Lightweight Dependency Injection Pattern
- **Scoped Services:** Lifecycle per Request/Connection

### 1.4.3 Shared Components
- Components zwischen Blazor und MAUI teilen
- Platform-spezifischer Code über Partial Classes
- Conditional Compilation für OS-spezifische Logik

## 1.5 MAUI-Architektur

### 1.5.1 MVVM mit CommunityToolkit.Mvvm
```
Shell (Navigation)
├── Views (XAML)
├── ViewModels (CommunityToolkit.Mvvm)
└── Models (Business Logic)
```

### 1.5.2 Navigations-Patterns
- **Shell-Navigation:** Built-in Routing für TAB/Hamburger Menus
- **Custom Navigation:** Für komplexe Szenarien

### 1.5.3 Platform-spezifischer Code
- Partial Classes für Platform-Gates
- `#if NET8_0_ANDROID` Conditional Compilation
- Platform-Services über Dependency Injection

## 1.6 API-Design

### 1.6.1 Minimal APIs vs. Controller
| Aspekt | Minimal APIs | Controller |
|--------|--------------|-----------|
| **Komplexität** | Einfach (klein) | Mittel (größer) |
| **Performance** | Marginale Vorteile | Bewährt |
| **Testing** | Direkter | Via DI |
| **Verwendung** | Microservices | Enterprise |

### 1.6.2 API Versioning
- URL-basiert: `/api/v1/users`
- Header-basiert: `Api-Version: 1.0`
- Query-Parameter: `?apiVersion=1.0`
- Strategie: Alte Versionen 2 Major-Releases lang unterstützen

### 1.6.3 DTOs vs. Domain Models
- DTOs für externe API-Contracts
- Domain Models bleiben intern
- AutoMapper für Transformationen
- Validation auf DTO-Ebene

### 1.6.4 Validation
- **FluentValidation:** Komplexe Regeln, wiederverwendbar
- **DataAnnotations:** Einfache Feldvalidierung
- **Custom Validators:** Business-Regeln

## 1.7 Related Skills

- blazor-patterns
- maui-patterns
- minimal-api-patterns
- aspire-architecture

## 1.8 Workflow

1. **Codebase scannen:** Existierende Patterns, Abhängigkeiten
2. **Anforderung verstehen:** Funktionale und nicht-funktionale Anforderungen
3. **Optionen präsentieren:** 2-3 Alternativen mit Vor-/Nachteilen
4. **Empfehlung geben:** Begründet mit konkreter Struktur
5. **Implementierung delegieren:** An dotnet-developer oder Spezialisten

## 1.9 Regeln

- Architekturentscheidungen **begründet**, nicht dogmatisch
- Alternativen präsentieren wenn nicht eindeutig
- Ist-Zustand berücksichtigen — Refactoring-Aufwand realistisch einschätzen
- YAGNI-Prinzip: Nicht über-engineern
- Keine Implementierung — nur Architektur-Entscheidungen treffen

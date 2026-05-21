---
name: documentation-patterns
description: Technische Dokumentation — README, API-Docs, Changelogs, Release Notes, XML-Doc Comments, Comment-Based Help
---

# 1. Documentation-Patterns Skill

## 1.1 Übersicht

Dieses Skill behandelt systematisches Schreiben von technischer Dokumentation für .NET und PowerShell Projekte. Es deckt README, API-Dokumentation, Changelogs und Inline-Dokumentation ab.

## 1.2 README.md

### 1.2.1 Struktur

1. **Projektbeschreibung:** Was macht das Projekt? Für wen?
2. **Voraussetzungen:** .NET Version, Tools, Konten
3. **Quick Start:** Minimale Schritte zum Laufen
4. **Konfiguration:** Umgebungsvariablen, appsettings.json
5. **Architektur:** Kurze Übersicht der Projektstruktur
6. **Contributing:** Wie kann man beitragen?
7. **License:** Lizenztyp

### 1.2.2 Best Practices
- Deutsch, prägnant, keine Prosa-Wüsten
- Code-Beispiele > Beschreibungen
- Copy-Paste-ready Quick Start
- Links zu weiterführenden Dokumentationen
- Badges für Status, Version, Build

### 1.2.3 Beispiel-Struktur

```markdown
# Projektname

Kurze Beschreibung in 1-2 Sätzen.

## Voraussetzungen

- .NET 10
- Visual Studio 2025 oder VS Code
- PowerShell 7.x

## Quick Start

```bash
git clone ...
cd project
dotnet build
dotnet run
```

## Konfiguration

### Umgebungsvariablen

| Variable | Beschreibung | Default |
|----------|-------------|---------|
| `API_KEY` | External API Key | Required |

### appsettings.json

```json
{
  "Logging": { "LogLevel": "Information" },
  "Database": { "ConnectionString": "..." }
}
```

## Architektur

[Kurze Übersicht der Folder-Struktur und Module]

## Contributing

[Wie kann man beitragen, PR-Prozess]
```

## 1.3 API-Dokumentation

### 1.3.1 XML-Doc Comments (C#)

Jede public Klasse, Methode, Property dokumentieren:

```csharp
/// <summary>
/// Erstellt einen neuen Benutzer im System.
/// </summary>
/// <param name="request">Die Registrierungsdaten des neuen Benutzers.</param>
/// <returns>Den erstellten Benutzer mit generierter ID.</returns>
/// <exception cref="ValidationException">Wenn die E-Mail-Adresse ungültig ist.</exception>
/// <example>
/// <code>
/// var user = await userService.CreateAsync(
///     new CreateUserRequest("test@example.com", "Max Mustermann"));
/// </code>
/// </example>
public async Task<UserDto> CreateAsync(CreateUserRequest request)
{
    // ...
}
```

### 1.3.2 XML-Doc Tags

| Tag | Zweck | Beispiel |
|-----|-------|---------|
| `<summary>` | Kurze Beschreibung | Mit Verb beginnen |
| `<param>` | Parameter-Dokumentation | Für jeden Parameter |
| `<returns>` | Rückgabewert | Outside void/Task |
| `<exception>` | Mögliche Exceptions | Häufige Fehler |
| `<example>` | Code-Beispiel | Nicht-triviale APIs |
| `<remarks>` | Detaillierte Erklärung | Zusätzlicher Kontext |
| `<see cref>` | Interne Link | Zu anderen Typen |

### 1.3.3 Comment-Based Help (PowerShell)

```powershell
function Get-Something {
    <#
    .SYNOPSIS
        Ruft Etwas ab basierend auf dem angegebenen Namen.

    .DESCRIPTION
        Durchsucht die Datenquelle nach Einträgen mit dem angegebenen
        Namen und gibt die gefundenen Ergebnisse zurück.

    .PARAMETER Name
        Der Name des gesuchten Elements. Unterstützt Wildcards.

    .PARAMETER Filter
        Optionaler Filter für weitere Einschränkung.

    .EXAMPLE
        Get-Something -Name 'Test*'
        
        Gibt alle Elemente zurück, deren Name mit 'Test' beginnt.

    .EXAMPLE
        Get-Something -Name 'Test*' -Filter 'Active'
        
        Gibt aktive Elemente zurück, deren Name mit 'Test' beginnt.

    .OUTPUTS
        [PSCustomObject] Das gefundene Element oder $null.

    .NOTES
        Erfordert Modul-Version 2.0 oder höher.

    .LINK
        https://github.com/...
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [string]$Filter
    )
    # ...
}
```

### 1.3.4 Comment-Based Help Tags

| Tag | Zweck |
|-----|-------|
| `.SYNOPSIS` | Kurze Beschreibung |
| `.DESCRIPTION` | Detaillierte Erklärung |
| `.PARAMETER` | Für jeden Parameter |
| `.EXAMPLE` | Mind. 1 Beispiel |
| `.OUTPUTS` | Rückgabetyp(en) |
| `.NOTES` | Zusätzliche Informationen |
| `.LINK` | Externe Referenzen |

## 1.4 Changelogs (CHANGELOG.md)

Format: [Keep a Changelog](https://keepachangelog.com/de/) + Conventional Commits

### 1.4.1 Struktur

```markdown
# Changelog

Alle wesentlichen Änderungen an diesem Projekt werden in dieser Datei
dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/)
und [Conventional Commits](https://www.conventionalcommits.org/de/).

## [Unreleased]

## [1.2.0] - 2026-03-21

### Breaking Changes
- `/api/v1/legacy` Endpoint entfernt (#40)
  - Migration: Verwende `/api/v2/` statt `/api/v1/`

### Hinzugefügt
- Benutzer-Export als CSV (#42)
- Health Check Endpoint für Monitoring (#45)

### Geändert
- API-Antwortformat auf RFC 7807 Problem Details umgestellt (#43)

### Behoben
- Fehler bei der Datumsformatierung in der Benutzeransicht (#44)

### Entfernt
- Veralteter `/api/v1/legacy` Endpoint (#40)

### Sicherheit
- Dependency Vulnerability in NuGet Package X behoben (CVE-2026-12345)

## [1.1.0] - 2026-03-01

...
```

### 1.4.2 Kategorisierung

Nutze diese Ordnung (Breaking Changes immer oben):

1. **Breaking Changes** — API-Breaking, Deprecations
2. **Hinzugefügt** — Neue Features (`feat`)
3. **Geändert** — Verbesserungen, Refactorings (`refactor`)
4. **Behoben** — Bugfixes (`fix`)
5. **Entfernt** — Deprecated Features entfernt
6. **Sicherheit** — Security-Fixes

## 1.5 Release Notes

Kompakter als Changelog, aus User-Perspektive:

```markdown
# Release 1.2.0

## Neue Features

### CSV-Export
Benutzerdaten können jetzt als CSV exportiert werden.
Nützlich für Reports und Daten-Migration.

## Verbesserungen

- API-Fehlermeldungen folgen jetzt dem RFC 7807 Standard
- Performance: 30% schnere Datenbankabfragen
- Health Check Endpoint für Kubernetes Liveness Probes

## Bugfixes

- Datumsanzeige in der Benutzeransicht korrigiert
- XSS-Vulnerability in Benutzer-Kommentaren gefixt

## Breaking Changes

- Der Endpoint `/api/v1/legacy` wurde entfernt.
  Migration: Verwende `/api/v2/` statt `/api/v1/`

## Installation

Upgrade via NuGet oder PowerShell Gallery.
```

## 1.6 Inline-Dokumentation

### 1.6.1 Wann Inline-Kommentare sinnvoll sind

**JA:**
- **Warum** etwas getan wird (nicht **was** — das sagt der Code)
- Business-Regeln, die nicht offensichtlich sind
- Workarounds mit Link zum GitHub Issue
- Performance-Gründe für unübliche Implementierungen

**NEIN:**
- Offensichtlicher Code (`// Increment counter` über `counter++`)
- Auskommentierter Code (löschen, Git hat die Historie)
- TODO ohne Issue-Referenz

### 1.6.2 Beispiele

**Gut:**
```csharp
// WORKAROUND: Blazor vor 10.0 hat Bug mit Cascading-Parametern
// wenn Component destruyiert und neu erstellt wird. 
// Issue: https://github.com/dotnet/aspnetcore/issues/xxxxx
// Kann entfernt werden nach .NET 11.0
var delay = RuntimeInformation.IsOSPlatform(OSPlatform.Windows) ? 100 : 0;
await Task.Delay(delay);

// Business rule: Order can only be placed if:
// 1. Customer has valid billing address
// 2. Total amount <= customer credit limit
// 3. Not in blocked countries
if (!ValidateOrderPlacement(order)) throw new OrderRejected();
```

**Schlecht:**
```csharp
// ❌ Offensichtlich was der Code macht
counter++; // Increment the counter

// ❌ Auskommentierter Code
// var oldWay = customer.GetById(id);

// ❌ TODO ohne Context
// TODO: Fix this later
```

## 1.7 Workflow

1. **Kontext verstehen:** Welcher Code? Für welches Issue?
2. **Zielgruppe:** Entwickler? Endbenutzer? Ops?
3. **Dokumentation schreiben:** Im passenden Format
4. **Konsistenz prüfen:** Passt zum Rest der Dokumentation?

## 1.8 Best Practices

- **Sprache:** Deutsch für alle Dokumentation
- **Code-Beispiele:** Müssen kompilier-/ausführbar sein
- **Keine Marketing:** Technisch präzise
- **Neben dem Code:** Nicht in separates Wiki
- **Versionieren:** Dokumentation gehört zu Releases
- **Verlinken:** Zu Issues, PRs, Referenzen

## 1.9 Related Skills

Keine direkten Cross-References erforderlich.

## 1.10 Regeln

- Technisch präzise, nicht zu akademisch
- Code-Beispiele sind Load-Bearing
- Dokumentation bei Breaking Changes pflicht
- Review-Prozess: Docs werden wie Code reviewed

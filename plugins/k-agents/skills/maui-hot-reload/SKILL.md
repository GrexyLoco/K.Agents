---
name: maui-hot-reload
description: ".NET MAUI Hot Reload — C# hot reload, XAML hot reload, Blazor Hybrid hot reload, dotnet watch, MetadataUpdateHandler, hot reload limitations and workarounds. USE FOR: troubleshooting hot reload failures, configuring dotnet watch for MAUI, understanding C# Hot Reload limitations. DO NOT USE FOR: general MAUI development (use maui-patterns) or build errors (use dotnet-build-diagnosis)."
---

# MAUI Hot Reload

Basiert auf: [davidortinau/maui-skills](https://github.com/davidortinau/maui-skills) (MIT, David Ortinau, Microsoft)

## Hot Reload Typen

| Typ | Was | Funktioniert bei |
|-----|-----|-----------------|
| XAML Hot Reload | UI-Markup-Änderungen | Layout, Styles, Bindings |
| C# Hot Reload | Code-Änderungen | Methoden-Bodies, Lambdas, lokale Variablen |
| Blazor Hybrid | Razor/CSS | Blazor-Komponenten in MAUI |

## Häufige Probleme

### XAML Hot Reload geht nicht
1. **Visual Studio:** Tools → Optionen → Debugging → Hot Reload → XAML aktiviert?
2. **VS Code:** `dotnet watch` statt `dotnet run` verwenden
3. **Encoding:** XAML-Dateien müssen UTF-8 (BOM) sein
4. **MetadataUpdateHandler:** Registriert?

### C# Hot Reload Einschränkungen
Funktioniert **nicht** bei:
- Neuen Typen / Interfaces / Enums hinzufügen
- Generische Methoden-Signaturen ändern
- Statische Felder hinzufügen/entfernen
- Struct-Layouts ändern

Funktioniert bei:
- Methoden-Bodies ändern
- Lambda-Expressions ändern
- Lokale Variablen hinzufügen

### VS Code Setup
```bash
# Mit Hot Reload starten
dotnet watch --project MyMauiApp
```

### Environment Variables
```bash
# Hot Reload Debug-Ausgabe aktivieren
DOTNET_WATCH_DEBUG=1

# MetadataUpdate Logging
DOTNET_MODIFIABLE_ASSEMBLIES=debug
```

## MetadataUpdateHandler
```csharp
[assembly: MetadataUpdateHandler(typeof(HotReloadHandler))]

internal static class HotReloadHandler
{
    internal static void ClearCache(Type[]? updatedTypes) { }
    internal static void UpdateApplication(Type[]? updatedTypes)
    {
        // UI nach Hot Reload aktualisieren
        MainThread.BeginInvokeOnMainThread(() =>
        {
            // Page neu laden oder State refreshen
        });
    }
}
```

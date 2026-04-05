---
name: maui-performance
description: ".NET MAUI performance — profiling (dotnet trace, dotnet counters), compiled bindings, CollectionView vs ListView, layout optimization, startup time, AOT for Release, PublishTrimmed, image optimization. USE FOR: profiling slow MAUI apps, optimizing layout rendering, reducing startup time, enabling trimming. DO NOT USE FOR: general MAUI patterns (use maui-patterns) or .NET-wide AOT warnings (use dotnet-aot-compat)."
---

# MAUI Performance

Basiert auf: [davidortinau/maui-skills](https://github.com/davidortinau/maui-skills) (MIT, David Ortinau, Microsoft)

## Profiling
```bash
# dotnet-trace für CPU-Profiling
dotnet trace collect --process-id <PID> --providers Microsoft-DotNETCore-SampleProfiler

# dotnet-counters für Live-Metriken
dotnet counters monitor --process-id <PID> --counters System.Runtime
```

## Compiled Bindings (Pflicht)
```xml
<!-- IMMER Compiled Bindings verwenden -->
<Label Text="{Binding UserName, Mode=OneWay}" />

<!-- In .csproj erzwingen -->
<PropertyGroup>
  <StrictXamlCompilation>true</StrictXamlCompilation>
</PropertyGroup>
```

## Layout-Optimierung
- `CollectionView` statt `ListView` (immer)
- Flache Visual Trees: max 3-4 Nesting-Ebenen
- `Grid` statt verschachtelte `StackLayout`
- `AbsoluteLayout` / `FlexLayout` für komplexe Layouts
- `BindableLayout` nur für kleine Listen (< 20 Items)

## Image-Optimierung
- Bilder auf Display-Auflösung skalieren (nicht 4000x3000 für 200x200)
- `Aspect="AspectFill"` oder `AspectFit` mit expliziten Dimensionen
- `CachingEnabled="True"` auf `UriImageSource`
- WebP (Android), HEIF/PNG (iOS) für plattformoptimale Formate
- SVG/Font Icons statt Bitmaps für Icons

## Startup-Zeit
```xml
<PropertyGroup>
  <!-- Interpreter für schnelleren Debug-Start -->
  <UseInterpreter Condition="'$(Configuration)' == 'Debug'">true</UseInterpreter>
  <!-- AOT für Production -->
  <RunAOTCompilation Condition="'$(Configuration)' == 'Release'">true</RunAOTCompilation>
  <EnableLLVM>true</EnableLLVM>
</PropertyGroup>
```
- Lazy Initialization für teure Services
- `CreateMauiApp()` schlank halten
- Splash Screen nutzen für wahrgenommene Performance

## Trimming & NativeAOT
```xml
<PropertyGroup Condition="'$(Configuration)' == 'Release'">
  <PublishTrimmed>true</PublishTrimmed>
  <TrimMode>full</TrimMode>
</PropertyGroup>
```

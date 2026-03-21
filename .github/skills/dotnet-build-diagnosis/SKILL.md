---
name: dotnet-build-diagnosis
description: .NET Build-Fehler systematisch diagnostizieren und beheben. Nutze diesen Skill bei MSBuild-Fehlern, NuGet-Konflikten, Restore-Problemen und Build-Performance-Optimierung. Basiert auf dotnet/skills (Microsoft).
---

# .NET Build-Fehler-Diagnose

Basiert auf: [dotnet/skills](https://github.com/dotnet/skills) (MIT, Microsoft .NET Team)

## Systematische Diagnose

### Schritt 1: Fehler klassifizieren
| Fehlertyp | Erkennung | Erste Aktion |
|-----------|-----------|-------------|
| CS-Fehler (CS0246, CS1061...) | Compiler-Fehler | Code oder Using prüfen |
| MSB-Fehler (MSB3027, MSB4...) | Build-System-Fehler | .csproj / Directory.Build.props prüfen |
| NU-Fehler (NU1101, NU1605...) | NuGet-Fehler | Package References prüfen |
| NETSDK-Fehler | SDK-Konfiguration | global.json, TargetFramework prüfen |

### Schritt 2: Diagnostik-Befehle
```bash
# Vollständiges Clean + Rebuild (erster Versuch)
dotnet clean && dotnet restore --force && dotnet build --no-incremental

# Detaillierte MSBuild-Ausgabe
dotnet build -v diag > build.log 2>&1

# NuGet-Abhängigkeitsbaum
dotnet list package --include-transitive

# Veraltete Pakete finden
dotnet list package --outdated

# Vulnerable Packages
dotnet list package --vulnerable --include-transitive
```

### Schritt 3: Häufige Probleme

**NU1605 (Downgrade detected):**
```xml
<PackageReference Include="Problematic.Package" Version="2.0.0">
  <NoWarn>NU1605</NoWarn>
</PackageReference>
<!-- Besser: Version explizit auf die höhere setzen -->
```

**NETSDK1045 (SDK Version):**
```json
// global.json prüfen
{
  "sdk": {
    "version": "10.0.100",
    "rollForward": "latestMinor"
  }
}
```

**Multi-Targeting Fehler:**
```xml
<TargetFrameworks>net10.0;net10.0-android;net10.0-ios</TargetFrameworks>
<!-- Bei Fehler: Plattform-spezifisch bedingt kompilieren -->
<ItemGroup Condition="$([MSBuild]::GetTargetPlatformIdentifier('$(TargetFramework)')) == 'android'">
  <PackageReference Include="Xamarin.AndroidX.Core" Version="..." />
</ItemGroup>
```

## Build-Performance
- `dotnet build --no-restore` wenn Restore nicht nötig
- `Directory.Build.props` für gemeinsame Properties
- `Directory.Packages.props` für Central Package Management
- Implicit Usings aktivieren: `<ImplicitUsings>enable</ImplicitUsings>`

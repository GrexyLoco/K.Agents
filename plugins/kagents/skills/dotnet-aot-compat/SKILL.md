---
name: dotnet-aot-compat
description: "Native AOT and trimming compatibility for .NET — IL analyzer warnings (IL2026, IL2070, IL2067, IL2072, IL3050), IsAotCompatible, DynamicallyAccessedMembers, source-generated serialization, reflection-free DI. USE FOR: resolving IL warnings, enabling AOT compilation, making libraries trim-safe. DO NOT USE FOR: general build errors (use dotnet-build-diagnosis) or runtime performance tuning (use database-performance or maui-performance)."
---

# 1. Native AOT & Trimming Kompatibilität

Basiert auf: [dotnet/skills](https://github.com/dotnet/skills) (MIT, Microsoft .NET Team)

## 1.1 AOT aktivieren
```xml
<PropertyGroup>
  <IsAotCompatible Condition="$([MSBuild]::IsTargetFrameworkCompatible('$(TargetFramework)', 'net8.0'))">true</IsAotCompatible>
</PropertyGroup>
```
Aktiviert automatisch `EnableTrimAnalyzer=true` und `EnableAotAnalyzer=true`.

## 1.2 Warnings analysieren
```bash
dotnet build MyProject.csproj --no-incremental 2>&1 | grep 'IL[0-9]\{4\}'
```

## 1.3 Häufige IL-Warnings

| Warning | Ursache | Fix |
|---------|---------|-----|
| IL2026 | Aufruf von `[RequiresUnreferencedCode]` | Aufruf vermeiden oder `[UnconditionalSuppressMessage]` mit Begründung |
| IL2070 | Reflection ohne `[DynamicallyAccessedMembers]` | Annotation am Type-Parameter hinzufügen |
| IL2067 | Unannotierter Type an annotierte Methode übergeben | `[DynamicallyAccessedMembers(DynamicallyAccessedMemberTypes.All)]` |
| IL2072 | Rückgabewert ohne Annotation | Annotation am Return-Type |
| IL2057 | `Type.GetType(string)` mit nicht-konstanter Variable | Konstante verwenden oder Pattern ändern |
| IL3050 | `[RequiresDynamicCode]` Aufruf | Source Generator oder Compile-Time Alternative |

## 1.4 Source-Generated Serialization (statt Reflection)
```csharp
[JsonSerializable(typeof(UserResponse))]
[JsonSerializable(typeof(List<UserResponse>))]
internal partial class AppJsonContext : JsonSerializerContext { }

// Nutzung
var json = JsonSerializer.Serialize(user, AppJsonContext.Default.UserResponse);
```

## 1.5 DI ohne Reflection
```csharp
// Statt Assembly-Scanning:
builder.Services.AddSingleton<IUserService, UserService>();
// Oder Source-Generated DI (ab .NET 10)
```

## 1.6 Regeln
- Nicht für .NET Framework (net4x) Projekte verwenden
- Bei Multi-Targeting (netstandard2.0;net10.0): Condition auf TFM
- Immer zuerst Warnings auflösen, dann AOT publishen testen

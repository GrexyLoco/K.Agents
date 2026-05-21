---
name: maui-blazor-hybrid
description: "Blazor Hybrid in .NET MAUI — BlazorWebView setup, JavaScript-C# interop (IJSRuntime, JSInvokable), shared Razor Class Libraries, platform-specific DI services, CSS isolation, NavigationManager. USE FOR: embedding Blazor in MAUI apps, sharing UI between MAUI and Blazor Web, implementing JS interop. DO NOT USE FOR: standalone Blazor Server/WASM (use blazor-patterns) or general MAUI views (use maui-patterns)."
---

# 1. MAUI Blazor Hybrid

Basiert auf: [davidortinau/maui-skills](https://github.com/davidortinau/maui-skills) (MIT, David Ortinau, Microsoft)

## 1.1 BlazorWebView Setup
```xml
<!-- In .csproj -->
<PackageReference Include="Microsoft.AspNetCore.Components.WebView.Maui" Version="..." />
```

```csharp
// MauiProgram.cs
builder.Services.AddMauiBlazorWebView();
#if DEBUG
builder.Services.AddBlazorWebViewDeveloperTools();
#endif
```

```xml
<!-- In MainPage.xaml -->
<BlazorWebView HostPage="wwwroot/index.html">
    <BlazorWebView.RootComponents>
        <RootComponent Selector="#app" ComponentType="{x:Type local:Routes}" />
    </BlazorWebView.RootComponents>
</BlazorWebView>
```

## 1.2 JavaScript ↔ C# Interop
```csharp
// C# → JavaScript
await JSRuntime.InvokeVoidAsync("showAlert", "Hallo aus C#!");

// JavaScript → C#
[JSInvokable]
public static Task<string> GetDataFromCSharp()
{
    return Task.FromResult("Daten aus C#");
}
```

## 1.3 Shared Components (MAUI + Blazor Web)
```
SharedComponents/
├── SharedComponents.csproj       # RCL (Razor Class Library)
├── Pages/
│   ├── Home.razor
│   └── UserList.razor
└── Components/
    └── DataGrid.razor

MauiApp/
├── MauiApp.csproj               # Referenziert SharedComponents
└── wwwroot/

BlazorWebApp/
├── BlazorWebApp.csproj          # Referenziert SharedComponents
└── wwwroot/
```

## 1.4 Platform-spezifische Services
```csharp
// Interface in SharedComponents
public interface IDeviceService { string GetPlatform(); }

// MAUI-Implementierung
public class MauiDeviceService : IDeviceService
{
    public string GetPlatform() => DeviceInfo.Platform.ToString();
}

// Web-Implementierung
public class WebDeviceService : IDeviceService
{
    public string GetPlatform() => "Web";
}

// DI-Registrierung je nach Host
builder.Services.AddSingleton<IDeviceService, MauiDeviceService>();  // MAUI
builder.Services.AddSingleton<IDeviceService, WebDeviceService>();   // Web
```

## 1.5 Regeln
- `wwwroot/` Ordner muss in MAUI-Projekt existieren
- Static Assets in SharedComponents als Embedded Resources
- CSS Isolation funktioniert in Blazor Hybrid
- `NavigationManager` unterscheidet sich zwischen MAUI und Web

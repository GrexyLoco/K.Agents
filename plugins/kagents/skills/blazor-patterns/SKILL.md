---
name: blazor-patterns
description: "Blazor Server, WASM, Hybrid, Static SSR patterns for .NET 10 — render mode decisions, component architecture, code-behind, state management, EventCallback, cascading values, @key, IDisposable. USE FOR: building Blazor components, choosing render modes, implementing state management. DO NOT USE FOR: Blazor inside MAUI (use maui-blazor-hybrid) or Blazor UI E2E tests (use playwright-blazor-testing)."
---

# 1. Blazor Patterns (.NET 10)

## 1.1 Render Modes

| Mode | Wann verwenden |
|------|---------------|
| Static SSR | Content-Seiten, SEO-relevant, kein Interaktivitätsbedarf |
| Interactive Server | Echtzeit-Daten, Server-Ressourcen nötig, kein Offline |
| Interactive WASM | Offline-Fähigkeit, Client-Ressourcen, wenig Server-Last |
| Interactive Auto | Server-Start, WASM-Übernahme nach Download |

```razor
@rendermode InteractiveServer
@rendermode InteractiveWebAssembly
@rendermode InteractiveAuto
```

## 1.2 Komponenten-Architektur

### 1.2.1 Code-Behind bei Komplexität
```csharp
// UserList.razor.cs
public partial class UserList : ComponentBase
{
    [Parameter] public IReadOnlyList<User> Users { get; set; } = [];
    [Parameter] public EventCallback<User> OnUserSelected { get; set; }
    
    private async Task SelectUser(User user) => await OnUserSelected.InvokeAsync(user);
}
```

### 1.2.2 State Management
- **Komponenten-State:** `private` Felder in der Komponente
- **Parent→Child:** `[Parameter]`
- **Child→Parent:** `EventCallback<T>`
- **Feature-State:** Scoped Service mit `INotifyPropertyChanged` oder Fluxor
- **App-weiter State:** `CascadingValue` oder Singleton Service

### 1.2.3 Anti-Patterns vermeiden
- Kein `StateHasChanged()` ohne Notwendigkeit
- Keine `[Parameter]` die intern mutiert werden
- Kein `OnParametersSet` für teure Operationen ohne Guard
- `IDisposable` implementieren bei Event-Subscriptions
- `@key` auf Listen-Elementen für effizientes Diffing

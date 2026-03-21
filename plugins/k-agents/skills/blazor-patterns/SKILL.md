---
name: blazor-patterns
description: Blazor Server/WASM/Hybrid Patterns für .NET 10. Nutze diesen Skill bei Blazor-Komponenten-Entwicklung, State Management und Render Mode Entscheidungen.
---

# Blazor Patterns (.NET 10)

## Render Modes

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

## Komponenten-Architektur

### Code-Behind bei Komplexität
```csharp
// UserList.razor.cs
public partial class UserList : ComponentBase
{
    [Parameter] public IReadOnlyList<User> Users { get; set; } = [];
    [Parameter] public EventCallback<User> OnUserSelected { get; set; }
    
    private async Task SelectUser(User user) => await OnUserSelected.InvokeAsync(user);
}
```

### State Management
- **Komponenten-State:** `private` Felder in der Komponente
- **Parent→Child:** `[Parameter]`
- **Child→Parent:** `EventCallback<T>`
- **Feature-State:** Scoped Service mit `INotifyPropertyChanged` oder Fluxor
- **App-weiter State:** `CascadingValue` oder Singleton Service

### Anti-Patterns vermeiden
- Kein `StateHasChanged()` ohne Notwendigkeit
- Keine `[Parameter]` die intern mutiert werden
- Kein `OnParametersSet` für teure Operationen ohne Guard
- `IDisposable` implementieren bei Event-Subscriptions
- `@key` auf Listen-Elementen für effizientes Diffing

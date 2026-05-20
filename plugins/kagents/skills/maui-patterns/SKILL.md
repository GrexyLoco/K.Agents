---
name: maui-patterns
description: ".NET MAUI cross-platform patterns — MVVM (CommunityToolkit.Mvvm, ObservableProperty, RelayCommand), Shell navigation, ContentPage, CollectionView, platform-specific partial classes, state management. USE FOR: building MAUI views, implementing MVVM, configuring Shell navigation. DO NOT USE FOR: performance tuning (use maui-performance), accessibility (use maui-accessibility), or Blazor in MAUI (use maui-blazor-hybrid)."
---

# 1. .NET MAUI Patterns

## 1.1 MVVM mit CommunityToolkit.Mvvm

```csharp
public partial class UserViewModel(IUserService userService) : ObservableObject
{
    [ObservableProperty]
    private string _searchText = string.Empty;

    [ObservableProperty]
    private ObservableCollection<User> _users = [];

    [RelayCommand]
    private async Task SearchAsync()
    {
        var results = await userService.SearchAsync(SearchText);
        Users = new ObservableCollection<User>(results);
    }
}
```

## 1.2 Shell-Navigation
```csharp
// Registrierung
Routing.RegisterRoute(nameof(UserDetailPage), typeof(UserDetailPage));

// Navigation mit Query Parameters
await Shell.Current.GoToAsync($"{nameof(UserDetailPage)}?userId={user.Id}");

// Empfang
[QueryProperty(nameof(UserId), "userId")]
public partial class UserDetailViewModel : ObservableObject
{
    [ObservableProperty] private string _userId = string.Empty;
}
```

## 1.3 Platform-spezifischer Code
```csharp
// Partial Classes
public partial class DeviceService
{
    public partial string GetDeviceInfo();
}

// Platforms/Android/DeviceService.cs
public partial class DeviceService
{
    public partial string GetDeviceInfo() => Android.OS.Build.Model ?? "Unknown";
}
```

## 1.4 Regeln
- UI-Updates immer auf Main Thread (`MainThread.BeginInvokeOnMainThread`)
- Lifecycle korrekt: `OnAppearing`/`OnDisappearing` für Subscriptions
- Keine Business-Logik in Code-Behind — alles im ViewModel
- Blazor Hybrid: Shared Components zwischen MAUI und Blazor Web nutzen

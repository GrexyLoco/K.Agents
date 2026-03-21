---
name: csharp-patterns
description: Moderne C# 14 / .NET 10 Patterns und Konventionen. Nutze diesen Skill bei jeder C#-Implementierung für aktuelle Sprachfeatures, Naming Conventions und Best Practices.
---

# C# 14 / .NET 10 Patterns

## Sprachfeatures (immer verwenden)

### Primary Constructors
```csharp
// ✅ Gut
public class UserService(IUserRepository repository, ILogger<UserService> logger);

// ❌ Vermeiden
public class UserService
{
    private readonly IUserRepository _repository;
    public UserService(IUserRepository repository) => _repository = repository;
}
```

### Collection Expressions
```csharp
int[] numbers = [1, 2, 3];
List<string> names = ["Alice", "Bob"];
ReadOnlySpan<byte> bytes = [0x00, 0xFF];
```

### Pattern Matching
```csharp
var result = status switch
{
    HttpStatusCode.OK => HandleSuccess(),
    HttpStatusCode.NotFound => HandleNotFound(),
    >= HttpStatusCode.InternalServerError => HandleServerError(),
    _ => HandleUnexpected()
};
```

### Records für DTOs
```csharp
public record CreateUserRequest(string Email, string DisplayName);
public record UserResponse(Guid Id, string Email, string DisplayName, DateTime CreatedAt);
```

### Required Members
```csharp
public class Configuration
{
    public required string ConnectionString { get; init; }
    public required int MaxRetries { get; init; }
}
```

## Naming Conventions

| Element | Convention | Beispiel |
|---------|-----------|---------|
| Klasse/Record | PascalCase | `UserService` |
| Interface | IPascalCase | `IUserRepository` |
| Methode | PascalCase | `GetUserByIdAsync` |
| Property | PascalCase | `DisplayName` |
| Parameter | camelCase | `userId` |
| Lokale Variable | camelCase | `currentUser` |
| Private Field | _camelCase | `_repository` |
| Konstante | PascalCase | `MaxRetryCount` |
| Async Methode | Suffix `Async` | `CreateUserAsync` |

## Pflicht-Patterns

- **File-scoped Namespaces** immer
- **Nullable Reference Types** immer aktiviert
- **Global Usings** in `GlobalUsings.cs`
- **Sealed Classes** als Default
- **Keine `async void`** — nur `async Task`
- **Keine Magic Strings** — Constants oder Enums

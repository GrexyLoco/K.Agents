---
name: csharp-patterns
description: "C# 14 / .NET 10 patterns — primary constructors, collection expressions, pattern matching, records, required members, nullable reference types, file-scoped namespaces, sealed classes, naming conventions. USE FOR: writing modern C# code, applying .NET 10 language features, enforcing naming and style conventions. DO NOT USE FOR: concurrency (use csharp-concurrency-patterns) or EF Core entities (use efcore-patterns)."
---

# 1. C# 14 / .NET 10 Patterns

## 1.1 Sprachfeatures (immer verwenden)

### 1.1.1 Primary Constructors
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

### 1.1.2 Collection Expressions
```csharp
int[] numbers = [1, 2, 3];
List<string> names = ["Alice", "Bob"];
ReadOnlySpan<byte> bytes = [0x00, 0xFF];
```

### 1.1.3 Pattern Matching
```csharp
var result = status switch
{
    HttpStatusCode.OK => HandleSuccess(),
    HttpStatusCode.NotFound => HandleNotFound(),
    >= HttpStatusCode.InternalServerError => HandleServerError(),
    _ => HandleUnexpected()
};
```

### 1.1.4 Records für DTOs
```csharp
public record CreateUserRequest(string Email, string DisplayName);
public record UserResponse(Guid Id, string Email, string DisplayName, DateTime CreatedAt);
```

### 1.1.5 Required Members
```csharp
public class Configuration
{
    public required string ConnectionString { get; init; }
    public required int MaxRetries { get; init; }
}
```

## 1.2 Naming Conventions

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

## 1.3 Pflicht-Patterns

- **File-scoped Namespaces** immer
- **Nullable Reference Types** immer aktiviert
- **Global Usings** in `GlobalUsings.cs`
- **Sealed Classes** als Default
- **Keine `async void`** — nur `async Task`
- **Keine Magic Strings** — Constants oder Enums

---
name: minimal-api-patterns
description: ASP.NET Core minimal API patterns for .NET 10. Use this skill when building REST APIs with minimal API syntax.

# Minimal API Patterns (.NET 10)

## Endpoint-Gruppen
```csharp
var users = app.MapGroup("/api/users")
    .WithTags("Users")
    .RequireAuthorization();

users.MapGet("/", GetUsersAsync);
users.MapGet("/{id:guid}", GetUserByIdAsync);
users.MapPost("/", CreateUserAsync);
users.MapPut("/{id:guid}", UpdateUserAsync);
users.MapDelete("/{id:guid}", DeleteUserAsync);
```

## Typed Results
```csharp
static async Task<Results<Ok<UserResponse>, NotFound, ValidationProblem>> GetUserByIdAsync(
    Guid id,
    IUserService userService)
{
    var user = await userService.GetByIdAsync(id);
    return user is null
        ? TypedResults.NotFound()
        : TypedResults.Ok(user.ToResponse());
}
```

## Request Validation
```csharp
users.MapPost("/", async (CreateUserRequest request, IValidator<CreateUserRequest> validator, IUserService service) =>
{
    var result = await validator.ValidateAsync(request);
    if (!result.IsValid)
        return Results.ValidationProblem(result.ToDictionary());
    
    var user = await service.CreateAsync(request);
    return Results.Created($"/api/users/{user.Id}", user.ToResponse());
});
```

## Regeln
- Request/Response als Records, nicht Domain Models exponieren
- `TypedResults` statt `Results` (bessere OpenAPI-Generierung)
- Endpoint-Handler als `static` Methoden oder in Endpoint-Klassen
- Filter für Cross-Cutting Concerns (Logging, Validation)

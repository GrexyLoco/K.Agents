---
name: api-design-patterns
description: "API-Design-Muster — Minimal APIs vs. Controller, TypedResults, Versioning, DTOs, Validation. USE FOR: designing REST API structure, implementing request/response patterns, versioning strategies. DO NOT USE FOR: Minimal API syntax details (use minimal-api-patterns) or authentication (use authentication-patterns)."
---

# 1. API-Design-Muster

## 1.1 Minimal APIs vs. Controller-Based

| Aspekt | Minimal API | Controller |
|---|---|---|
| Boilerplate | Minimal | Mehr Code |
| Testability | Einfach (pure functions) | Einfach (unit testable) |
| Middleware Integration | Inline möglich | Global/per-controller |
| Organizational Scale | <50 Endpoints | >100 Endpoints empfohlen |
| OpenAPI Generation | Automatisch (mit Konfiguration) | Automatisch |

**Regel:** Minimal APIs für <50 Endpoints oder Microservices; Controller für Enterprise APIs mit vielen Cross-Cutting Concerns.

## 1.2 TypedResults Pattern

Ersetze `Results.*` mit `TypedResults.*` für bessere OpenAPI-Dokumentation:

```csharp
// ❌ Schwach: Results
static Task<IResult> GetUser(Guid id) =>
    Task.FromResult<IResult>(Results.Ok(new UserDto { Id = id }));

// ✅ Stark: TypedResults
static async Task<Results<Ok<UserDto>, NotFound>> GetUserAsync(
    Guid id,
    IUserService service)
{
    var user = await service.GetByIdAsync(id);
    return user is null
        ? TypedResults.NotFound()
        : TypedResults.Ok(user.ToDto());
}
```

**Vorteil:** Compiler validates Rückgabetypen; OpenAPI generiert korrekte Statuscode-Schemata.

## 1.3 API Versioning

**1. Query-Parameter (einfach, deprecated)**
```
GET /api/users?api-version=1.0
```

**2. Header (implicit)**
```
GET /api/users
api-version: 1.0
```

**3. URL-Path (explicit, empfohlen)**
```
GET /api/v1/users
GET /api/v2/users
```

**Mit Minimal API:**
```csharp
var v1 = app.MapGroup("/api/v1").WithTags("v1");
var v2 = app.MapGroup("/api/v2").WithTags("v2");

v1.MapGet("/users", GetUsersV1);
v2.MapGet("/users", GetUsersV2);
```

## 1.4 DTOs und Validation

**Request DTO:**
```csharp
public record CreateUserRequest(
    [property: Required] string Email,
    [property: MinLength(3)] string Name);

public class CreateUserRequestValidator : AbstractValidator<CreateUserRequest>
{
    public CreateUserRequestValidator()
    {
        RuleFor(x => x.Email).EmailAddress();
        RuleFor(x => x.Name).NotEmpty();
    }
}
```

**Validation Pipeline:**
```csharp
users.MapPost("/", async (CreateUserRequest req, IValidator<CreateUserRequest> val, IUserService svc) =>
{
    var result = await val.ValidateAsync(req);
    if (!result.IsValid)
        return Results.ValidationProblem(result.ToDictionary());
    return Results.Created($"/api/users/{req.Email}", await svc.CreateAsync(req));
});
```

## 1.5 REST Best Practices

- **Naming:** Plural nouns (`/users`, `/orders`), nicht Verben (`/getUsers`)
- **Status Codes:** 200 OK, 201 Created, 400 Bad Request, 404 Not Found, 409 Conflict, 500 Internal Server Error
- **Content Negotiation:** Accept header support (JSON, XML) via `Produces()`, `Accepts()`
- **Pagination:** `?page=1&pageSize=20` mit Link headers (RFC 5988)
- **Filtering:** `?name=john&status=active` mit strongly-typed query objects


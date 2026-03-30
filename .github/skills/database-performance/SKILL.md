---
name: database-performance
description: EF Core query performance — N+1 detection, compiled queries, split queries, query tags, AsNoTracking, index strategy (composite, filtered, covering), read/write DbContext separation. USE FOR: diagnosing slow queries, optimizing EF Core performance, designing database indexes. DO NOT USE FOR: DbContext setup or migrations (use efcore-patterns) or general database schema design (use database-engineer agent).
---

# Database Performance (EF Core)

Adaptiert von: [Aaronontheweb/dotnet-skills](https://github.com/Aaronontheweb/dotnet-skills) (MIT)

## N+1 Query Erkennung
```csharp
// ❌ N+1 Problem
var users = await context.Users.ToListAsync();
foreach (var user in users)
{
    var orders = user.Orders; // Lazy Load = 1 Query pro User!
}

// ✅ Eager Loading
var users = await context.Users
    .Include(u => u.Orders)
    .AsNoTracking()
    .ToListAsync();

// ✅ Projection (noch besser)
var dtos = await context.Users
    .Select(u => new UserWithOrderCountDto(u.Id, u.Email, u.Orders.Count))
    .ToListAsync();
```

## Split Queries
```csharp
// Bei Include-Chains > 2 Ebenen: AsSplitQuery()
var orders = await context.Orders
    .Include(o => o.Items)
        .ThenInclude(i => i.Product)
            .ThenInclude(p => p.Category)
    .AsSplitQuery()  // Verhindert Cartesian Explosion
    .ToListAsync();
```

## Compiled Queries (Hot Paths)
```csharp
private static readonly Func<AppDbContext, Guid, Task<User?>> GetUserById =
    EF.CompileAsyncQuery((AppDbContext ctx, Guid id) =>
        ctx.Users.AsNoTracking().FirstOrDefault(u => u.Id == id));

// Nutzung
var user = await GetUserById(context, userId);
```

## Query Tags (Debugging)
```csharp
var users = await context.Users
    .TagWith("GetActiveUsers - UserService.cs:42")
    .Where(u => u.IsActive)
    .ToListAsync();
// Tag erscheint im SQL-Log → einfache Zuordnung
```

## Index-Strategie
```csharp
// Häufige WHERE-Klausel → Index
builder.HasIndex(u => u.Email).IsUnique();

// Composite Index für Multi-Column-Queries
builder.HasIndex(o => new { o.UserId, o.CreatedAt });

// Filtered Index für Soft-Delete
builder.HasIndex(u => u.Email)
    .HasFilter("[IsDeleted] = 0");

// Covering Index (Include)
builder.HasIndex(u => u.LastName)
    .IncludeProperties(u => new { u.FirstName, u.Email });
```

## Read/Write Separation
```csharp
// Separate DbContexte für Read und Write
services.AddDbContext<ReadDbContext>(o => o
    .UseSqlServer(config["ReadReplica"])
    .UseQueryTrackingBehavior(QueryTrackingBehavior.NoTracking));

services.AddDbContext<WriteDbContext>(o => o
    .UseSqlServer(config["Primary"]));
```

## Performance-Checkliste
- [ ] `AsNoTracking()` bei allen Read-Only Queries
- [ ] Keine N+1 Queries (Include oder Projection)
- [ ] `AsSplitQuery()` bei tiefen Include-Chains
- [ ] Compiled Queries für häufig aufgerufene Abfragen
- [ ] Query Tags für Debugging
- [ ] Indexes für WHERE/ORDER BY Spalten
- [ ] `Select()` Projection statt volle Entities laden

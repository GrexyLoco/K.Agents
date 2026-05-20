---
name: efcore-patterns
description: "Entity Framework Core for .NET 10 \u2014 DbContext design, IEntityTypeConfiguration, Fluent API, migrations, seed data, query patterns (AsNoTracking, Include, projection). USE FOR: designing EF Core entities, creating migrations, writing optimized queries with Fluent API. DO NOT USE FOR: advanced query performance tuning or index strategy (use database-performance)."
---

# 1. EF Core Patterns

## 1.1 Entity-Konfiguration (Fluent API)
```csharp
public class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        builder.HasKey(u => u.Id);
        builder.Property(u => u.Email).IsRequired().HasMaxLength(256);
        builder.HasIndex(u => u.Email).IsUnique();
        builder.Property(u => u.CreatedAt).HasDefaultValueSql("GETUTCDATE()");
        builder.OwnsOne(u => u.Address);
    }
}
```

## 1.2 Query-Patterns
```csharp
// Read-Only (immer AsNoTracking)
var users = await context.Users.AsNoTracking().TagWith("GetAllUsers").ToListAsync();

// Split Query bei tiefen Includes
var orders = await context.Orders
    .Include(o => o.Items).ThenInclude(i => i.Product)
    .AsSplitQuery()
    .ToListAsync();

// Projection statt Full Entity
var dtos = await context.Users
    .Select(u => new UserDto(u.Id, u.Email, u.DisplayName))
    .ToListAsync();
```

## 1.3 Migration-Regeln
- Sprechende Namen: `AddUserEmailUniqueIndex`, nicht `Migration_001`
- `Down()` immer implementieren
- Seed Data über `HasData()` oder dedizierte Migration
- Idempotent: `dotnet ef database update` muss mehrfach laufen können
- Keine Datenverlust-Operationen ohne explizite Warnung

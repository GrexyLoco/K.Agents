---
name: efcore-patterns
description: Entity Framework Core patterns for .NET 10. Use this skill for DbContext design, Fluent API, migrations, and query optimization.

# EF Core Patterns

## Entity-Konfiguration (Fluent API)
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

## Query-Patterns
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

## Migration-Regeln
- Sprechende Namen: `AddUserEmailUniqueIndex`, nicht `Migration_001`
- `Down()` immer implementieren
- Seed Data über `HasData()` oder dedizierte Migration
- Idempotent: `dotnet ef database update` muss mehrfach laufen können
- Keine Datenverlust-Operationen ohne explizite Warnung

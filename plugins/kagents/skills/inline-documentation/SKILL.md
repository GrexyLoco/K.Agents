---
name: inline-documentation
description: Inline-Dokumentation — Workarounds, Business Rules, Wann/Wann-nicht kommentieren. USE FOR: deciding when to add code comments, explaining workarounds and business rules, enforcing comment discipline. DO NOT USE FOR: method-level docs (use api-documentation) or README content (use readme-patterns).
---

# 1. Inline-Dokumentation

## 1.1 When to Comment

**Kommentare schreiben für:**

### 1.1.1 Workarounds mit Bug-Referenz
```csharp
// Workaround: DateOnly.FromDateTime() throws for dates before 1900
// See: https://github.com/dotnet/runtime/issues/50476
// Remove once we drop .NET 7 support
var dateOnly = new DateTime(year, month, day).Date.TryConvert();
```

### 1.1.2 Non-obvious Business Rules
```csharp
// Invoices for government agencies must use VAT ID format,
// not tax number. User discovered this during audit – keep explicit.
if (customer.IsGovernmentAgency)
    line.VatIdFormat = VatIdFormat.FullFormat;
```

### 1.1.3 Subtle Invariants (Ordering, State)
```csharp
// MUST cache user roles AFTER permission sync completes.
// If cached before, stale permissions cause authorization failures.
// (See incident 2026-02-15)
await service.SyncPermissionsAsync();
_roleCache = FetchRoles();
```

### 1.1.4 Performance Trade-off Justifications
```csharp
// Loading all items into memory (slow for huge lists) because
// we need to sort by computed field (TotalRevenue).
// Alternative: SQL window function would require DB schema change.
var items = await service.GetAllAsync();
var sorted = items.OrderByDescending(x => x.Orders.Sum(o => o.Amount)).ToList();
```

## 1.2 When NOT to Comment

**Nicht kommentieren:**

### 1.2.1 Self-documenting Code
```csharp
// ❌ DON'T:
// Calculate the sum
var total = items.Sum(x => x.Price);

// ✅ DO:
var totalPrice = items.Sum(x => x.Price);
```

### 1.2.2 Obvious Implementations
```csharp
// ❌ DON'T:
// Increment counter
count++;

// ✅ DO: (no comment needed, name says it all)
successCount++;
```

### 1.2.3 Commented-out Code
```csharp
// ❌ DON'T:
// var oldWay = DateTime.Now.AddDays(1);
// var newWay = ...

// ✅ DO: Delete it. Git has the history.
var expiresAt = DateTime.UtcNow.AddHours(24);
```

### 1.2.4 TODO ohne Issue-Referenz
```csharp
// ❌ DON'T:
// TODO: Optimize this loop

// ✅ DO:
// TODO (Issue #1234): Optimize this loop – currently O(n²), should be O(n log n)
```

## 1.3 Comment Culture

**Rule: Comments explain "Why" – not "What"**

```csharp
// ❌ WRONG (What – code shows this):
// Create a new user with the request data
var user = new User(request);

// ✅ RIGHT (Why):
// Use UTC here because timezones are normalized in the DB
var user = new User(request) { CreatedAt = DateTime.UtcNow };
```

**Tone:**
- Explain non-obvious decisions
- Reference Issues for bugs/decisions
- Be concise – 1–3 lines max
- German or English, consistent per file

## 1.4 Example Patterns

### 1.4.1 Good: Documented Workaround
```csharp
// Workaround for .NET Framework regex timeout issue
// (https://github.com/dotnet/runtime/issues/1234)
// Regex.Match() fails without explicit timeout on huge inputs.
// Mitigation: Pre-validate input length. Remove once on .NET 9+.
if (input.Length > MaxPatternLength)
    throw new ValidationException("Input too large");

var match = Regex.Match(input, pattern, RegexOptions.None, TimeSpan.FromSeconds(1));
```

### 1.4.2 Good: Business Rule
```csharp
// Per finance dept (Issue #567): Premium users get 14-day trial,
// others get 7-day. This is contractual, not a technical decision.
var trialDays = customer.IsPremium ? 14 : 7;
```

### 1.4.3 Bad: No Comment Needed
```csharp
var isActive = user.Status == Status.Active && !user.IsDeleted;
```

### 1.4.4 Bad: Documenting the Wrong Thing
```csharp
// ❌ DON'T comment what (code shows this):
// Parse the JSON
var data = JsonSerializer.Deserialize<Data>(json);

// ✅ DO comment why (if non-obvious):
// Deserialize with PropertyNameCaseInsensitive=true
// because legacy API returns camelCase, but our schema expects PascalCase
var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
var data = JsonSerializer.Deserialize<Data>(json, options);
```

## 1.5 Guidelines

- **Density:** ~1 comment per 10–20 lines of code (not per line)
- **Placement:** Above the code block it explains, not at end of line
- **Length:** 1–3 lines. If explaining is longer, extract function instead.
- **Obsolescence:** Review comments during code review – remove stale ones.

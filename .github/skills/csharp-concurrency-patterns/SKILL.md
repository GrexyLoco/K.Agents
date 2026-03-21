---
name: csharp-concurrency-patterns
description: C# Concurrency-Patterns – async/await, Channels, SemaphoreSlim, CancellationToken, Task.WhenAll. Adaptiert von Aaronontheweb/dotnet-skills.
---

# C# Concurrency Patterns

Adaptiert von: [Aaronontheweb/dotnet-skills](https://github.com/Aaronontheweb/dotnet-skills) (MIT)

## Pattern-Auswahl

| Situation | Pattern |
|-----------|---------|
| I/O-bound (HTTP, DB, File) | `async/await` |
| Parallel CPU-bound | `Parallel.ForEachAsync` |
| Producer/Consumer | `Channel<T>` |
| Rate Limiting | `SemaphoreSlim` |
| Background Work | `IHostedService` / `BackgroundService` |
| Fire-and-Forget (mit Fehlerhandling) | `Task.Run` + Error-Handler |

## async/await (Grundregeln)
```csharp
// ✅ Korrekt
public async Task<User> GetUserAsync(Guid id, CancellationToken ct = default)
{
    return await repository.GetByIdAsync(id, ct);
}

// ❌ Verboten: async void (nur für Event-Handler)
// ❌ Verboten: .Result oder .Wait() (Deadlock-Gefahr)
// ❌ Verboten: Task.Run um async zu wrappen
```

## CancellationToken (Pflicht)
```csharp
// Immer als letzten Parameter durchreichen
public async Task<List<User>> SearchAsync(string query, CancellationToken ct = default)
{
    ct.ThrowIfCancellationRequested();
    return await context.Users
        .Where(u => u.Name.Contains(query))
        .ToListAsync(ct);
}
```

## Parallel mit Task.WhenAll
```csharp
// ✅ Parallel statt sequentiell
var (users, orders, stats) = await (
    userService.GetAllAsync(ct),
    orderService.GetRecentAsync(ct),
    statsService.GetDashboardAsync(ct)
).WhenAll();

// Extension für Tuple-Destructuring:
public static class TaskExtensions
{
    public static async Task<(T1, T2, T3)> WhenAll<T1, T2, T3>(
        this (Task<T1>, Task<T2>, Task<T3>) tasks)
    {
        await Task.WhenAll(tasks.Item1, tasks.Item2, tasks.Item3);
        return (tasks.Item1.Result, tasks.Item2.Result, tasks.Item3.Result);
    }
}
```

## Channel<T> (Producer/Consumer)
```csharp
var channel = Channel.CreateBounded<WorkItem>(100);

// Producer
async Task ProduceAsync(ChannelWriter<WorkItem> writer)
{
    await foreach (var item in GetItemsAsync())
    {
        await writer.WriteAsync(item);
    }
    writer.Complete();
}

// Consumer
async Task ConsumeAsync(ChannelReader<WorkItem> reader, CancellationToken ct)
{
    await foreach (var item in reader.ReadAllAsync(ct))
    {
        await ProcessAsync(item, ct);
    }
}
```

## SemaphoreSlim (Rate Limiting)
```csharp
private static readonly SemaphoreSlim _semaphore = new(maxConcurrency: 10);

public async Task<Result> ProcessWithLimitAsync(CancellationToken ct)
{
    await _semaphore.WaitAsync(ct);
    try
    {
        return await DoExpensiveWorkAsync(ct);
    }
    finally
    {
        _semaphore.Release();
    }
}
```

## Thread-Safety
- `ConcurrentDictionary<K,V>` statt `Dictionary` + Lock
- `Interlocked.Increment` statt `lock { counter++ }`
- `ImmutableList<T>` / `FrozenDictionary<K,V>` für Read-Heavy Szenarien
- `lock` nur für kurze, synchrone Operationen
- Nie `async` Code innerhalb von `lock` — verwende `SemaphoreSlim`

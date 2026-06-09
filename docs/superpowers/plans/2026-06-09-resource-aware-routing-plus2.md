# ResourceGate Ausbau +2 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Den ResourceGate um zwei opt-in, read-only/best-effort Features erweitern: (A) lokalen Ollama-Prozess beim Start auf below-normal Priorität setzen; (B) Live-Inferenz-Telemetrie (Latenz + RAM-Delta) erfassen und in `learned-stats.json` persistieren — als Datenquelle für manuelle Mapping-Pflege, OHNE Laufzeit-Admission-Änderung.

**Architecture:** Additiv auf MVP + +1. Zwei neue Config-Flags (Default false). `OllamaPriorityService` (HostedService) nutzt eine testbare `IProcessController`-Abstraktion. `LocalStatsStore` (per-install `learned-stats.json`) wird vom `OllamaProvider` nach lokaler Inferenz mit Latenz (Stopwatch) + RAM-Delta (2-Punkt-GC) gefüttert. macOS NICHT unterstützt.

**Tech Stack:** C# / .NET 10, ASP.NET Core (IHostedService), source-generated JSON, `System.Diagnostics.Process`, TUnit.

**Spec:** [docs/superpowers/specs/2026-06-09-resource-aware-routing-plus2-design.md](../specs/2026-06-09-resource-aware-routing-plus2-design.md)

**Basis:** MVP + +1 gemergt (Alpha `v1.21.0-alpha2`); 107 Tests grün. Alle 107 müssen grün bleiben.

---

## Konventionen (für jeden ausführenden Subagenten)

- Repo-Root `c:\Users\gkump\source\repos\1d70f\K.Agents`. Switchboard: `k.switchboard.net/src/K.Switchboard/`, Tests: `k.switchboard.net/tests/K.Switchboard.Tests/`.
- ALREADY auf Branch `feature/268-resource-gate-plus2` — NICHT wechseln/pushen.
- Build/Test aus `k.switchboard.net/`: `dotnet build` · `dotnet test` (TUnit; ganze Suite läuft).
- **VOR jedem Commit-Schritt, der C# ändert: `dotnet format K.Switchboard.slnx` aus `k.switchboard.net/`** (CI-Gate, nicht in build/test). Keine kompakten Multi-Initializer-Zeilen.
- AOT: standalone-(de)serialisierte Typen in `SwitchboardJsonContext` registrieren. Test-Projekt hat `JsonSerializerIsReflectionEnabledByDefault=false` → test-lokale source-gen-Contexts (wie `HardwareProfileCacheTests`).
- German XML-doc, English identifiers. **Commit:** `type(scope): description` — Description LOWERCASE erstes Wort (CI `commit-msg.ps1` prüft `^[A-Z]` → FAIL; auch Akronyme klein: `ollama`, `cpu`), Bulletpoint-Body, Footer `Ref #268` (KEIN Closes). Scope `switchboard`.
- Kein Push (erst auf Auftrag, mit Train-Check).

## File Structure

| Datei | Änderung |
|---|---|
| `SwitchboardOptions.cs` | `ResourceGateOptions`: `LowerOllamaPriority` (bool), `RecordLocalInferenceStats` (bool); `CreateDefault()`-Defaults (beide false). |
| `Resources/IProcessController.cs` / `ProcessController.cs` | Abstraktion: Prozesse nach Name finden + Priorität below-normal setzen. |
| `Resources/OllamaPriorityService.cs` | `IHostedService`: beim Start lokalen Ollama auf below-normal (opt-in, localhost-only, best-effort). |
| `Resources/LocalInferenceStats.cs` | `record` Aggregat pro Modell (Count/Avg/Max/Last/UpdatedOn). |
| `Resources/LocalStatsStore.cs` | Persistenz `learned-stats.json` (per-install, SemaphoreSlim); `Record(model, elapsedMs, ramDeltaMb, sizeMb)`. |
| `SwitchboardJsonContext.cs` | `Dictionary<string, LocalInferenceStats>` registrieren. |
| `Providers/OllamaProvider.cs` | Telemetrie (Stopwatch + 2-Punkt-GC) um den Inferenz-Call, `LocalStatsStore.Record` bei Erfolg (opt-in). |
| `Program.cs` | DI: `IProcessController`, `OllamaPriorityService` (HostedService), `LocalStatsStore`. |
| `.gitignore` | `learned-stats.json`. |
| `docs/*` | configuration/troubleshooting/resource-aware-routing/eval-measurement. |

---

## Task 1: Config-Flags (+ CreateDefault)

**Files:**
- Modify: `k.switchboard.net/src/K.Switchboard/SwitchboardOptions.cs`
- Test: `k.switchboard.net/tests/K.Switchboard.Tests/Resources/SwitchboardOptionsPlus2Tests.cs`

- [ ] **Step 1: Write the failing test**

Create `tests/K.Switchboard.Tests/Resources/SwitchboardOptionsPlus2Tests.cs`:

```csharp
namespace K.Switchboard.Tests.Resources;

public sealed class SwitchboardOptionsPlus2Tests
{
    [Test]
    public async Task CreateDefault_has_plus2_flags_off()
    {
        var opts = SwitchboardOptions.CreateDefault();
        await Assert.That(opts.ResourceGate.LowerOllamaPriority).IsFalse();
        await Assert.That(opts.ResourceGate.RecordLocalInferenceStats).IsFalse();
    }
}
```

- [ ] **Step 2: Run → COMPILE FAIL.** `dotnet test`.

- [ ] **Step 3: Add the two flags**

In `SwitchboardOptions.cs`, `ResourceGateOptions` record, after `LatencyContextReferenceTokens`:

```csharp
    /// <summary>Lokalen Ollama-Prozess beim Start auf below-normal Priorität setzen
    /// (nur localhost, best-effort). Default false (opt-in).</summary>
    public bool LowerOllamaPriority { get; init; }

    /// <summary>Live-Inferenz-Telemetrie (Latenz + RAM-Delta) in learned-stats.json erfassen.
    /// Read-only — ändert die Admission NICHT. Default false (opt-in).</summary>
    public bool RecordLocalInferenceStats { get; init; }
```

In `CreateDefault()` `ResourceGate`-Initializer: die beiden Flags sind per record-default `false` — explizit setzen für die ausgelieferte config.json (eine Zeile je Flag, format-safe):

```csharp
            LowerOllamaPriority = false,
            RecordLocalInferenceStats = false
```
(nach der letzten bestehenden Zeile `LatencyContextReferenceTokens = 4000` einfügen, Komma-Platzierung beachten.)

- [ ] **Step 4: Run → PASS.** `dotnet test`; `dotnet format K.Switchboard.slnx`.

- [ ] **Step 5: Commit**

`feat(switchboard): config-flags für prozess-priorität + telemetrie` — bullet body (LowerOllamaPriority + RecordLocalInferenceStats, beide opt-in default false; CreateDefault) + `Ref #268`. Stage SwitchboardOptions.cs + Testdatei.

---

## Task 2: IProcessController + ProcessController

**Files:**
- Create: `k.switchboard.net/src/K.Switchboard/Resources/IProcessController.cs`
- Create: `k.switchboard.net/src/K.Switchboard/Resources/ProcessController.cs`
- Test: `k.switchboard.net/tests/K.Switchboard.Tests/Resources/ProcessControllerTests.cs`

- [ ] **Step 1: Write the failing test**

Der produktive `ProcessController` ist dünn (umschließt `System.Diagnostics.Process`); echte Prozess-Manipulation ist nicht deterministisch testbar. Der Test prüft daher nur, dass `FindByName` für einen garantiert-nicht-existierenden Namen eine leere Liste liefert (kein Crash) und `TrySetBelowNormal` für eine ungültige PID `false` liefert (best-effort, kein Throw). Create `ProcessControllerTests.cs`:

```csharp
namespace K.Switchboard.Tests.Resources;

using K.Switchboard.Resources;

public sealed class ProcessControllerTests
{
    [Test]
    public async Task FindByName_returns_empty_for_unknown_process()
    {
        var ctrl = new ProcessController();
        var pids = ctrl.FindByName("definitely-not-a-real-process-xyz123");
        await Assert.That(pids).IsEmpty();
    }

    [Test]
    public async Task TrySetBelowNormal_returns_false_for_invalid_pid()
    {
        var ctrl = new ProcessController();
        // PID 0 / ein sehr unwahrscheinlicher Wert → kein Prozess → false, kein Throw.
        var ok = ctrl.TrySetBelowNormal(-1);
        await Assert.That(ok).IsFalse();
    }
}
```

- [ ] **Step 2: Run → COMPILE FAIL.** `dotnet test`.

- [ ] **Step 3: Implement**

Create `Resources/IProcessController.cs`:

```csharp
namespace K.Switchboard.Resources;

/// <summary>Testbare Abstraktion für Prozess-Suche + Prioritäts-Senkung (Maschinen-Schutz).</summary>
public interface IProcessController
{
    /// <summary>PIDs aller laufenden Prozesse mit dem (plattform-normalisierten) Namen.</summary>
    IReadOnlyList<int> FindByName(string processName);

    /// <summary>Setzt die Priorität des Prozesses auf below-normal. true = gesetzt, false = nicht möglich
    /// (Prozess weg / fehlende Rechte). Wirft NICHT.</summary>
    bool TrySetBelowNormal(int pid);
}
```

Create `Resources/ProcessController.cs`:

```csharp
namespace K.Switchboard.Resources;

using System.Diagnostics;

/// <summary>Produktive <see cref="IProcessController"/>-Implementierung über System.Diagnostics.Process.
/// <c>PriorityClass = BelowNormal</c> ist cross-platform (Windows: BELOW_NORMAL; Linux: positiver nice-Wert,
/// Senken braucht keine root-Rechte). Alle Operationen sind best-effort (schlucken Exceptions).</summary>
public sealed class ProcessController : IProcessController
{
    public IReadOnlyList<int> FindByName(string processName)
    {
        try
        {
            return Process.GetProcessesByName(processName).Select(p => p.Id).ToArray();
        }
        catch
        {
            return [];
        }
    }

    public bool TrySetBelowNormal(int pid)
    {
        try
        {
            using var proc = Process.GetProcessById(pid);
            proc.PriorityClass = ProcessPriorityClass.BelowNormal;
            return true;
        }
        catch
        {
            return false;   // Prozess weg, fehlende Rechte, nicht unterstützt → best-effort
        }
    }
}
```

- [ ] **Step 4: Run → PASS.** `dotnet test`; `dotnet format K.Switchboard.slnx`.

- [ ] **Step 5: Commit**

`feat(switchboard): IProcessController` → LOWERCASE: `feat(switchboard): process-controller-abstraktion` — bullet body (FindByName + TrySetBelowNormal best-effort; Process.PriorityClass cross-platform; testbar) + `Ref #268`. Stage beide Quell-Dateien + Testdatei.

---

## Task 3: OllamaPriorityService (HostedService)

**Files:**
- Create: `k.switchboard.net/src/K.Switchboard/Resources/OllamaPriorityService.cs`
- Test: `k.switchboard.net/tests/K.Switchboard.Tests/Resources/OllamaPriorityServiceTests.cs`

> Beim Start: wenn `LowerOllamaPriority` UND `OllamaBaseUrl`-Host lokal → alle `ollama`-Prozesse auf below-normal. best-effort, macOS-Skip. Die Kern-Logik wird in eine testbare Methode `ApplyOnce()` ausgelagert (der `IHostedService.StartAsync` ruft sie auf).

- [ ] **Step 1: Write the failing test**

Create `OllamaPriorityServiceTests.cs`. Nutzt einen Fake-`IProcessController`, der Aufrufe aufzeichnet:

```csharp
namespace K.Switchboard.Tests.Resources;

using K.Switchboard.Resources;

public sealed class OllamaPriorityServiceTests
{
    private sealed class FakeProcessController : IProcessController
    {
        public List<int> LoweredPids { get; } = [];
        public int[] Found { get; init; } = [];
        public IReadOnlyList<int> FindByName(string processName) => Found;
        public bool TrySetBelowNormal(int pid) { LoweredPids.Add(pid); return true; }
    }

    private static OllamaPriorityService Build(FakeProcessController ctrl, bool enabled, string ollamaUrl)
    {
        var opts = new SwitchboardOptions
        {
            OllamaBaseUrl = ollamaUrl,
            ResourceGate = new ResourceGateOptions { LowerOllamaPriority = enabled }
        };
        return new OllamaPriorityService(ctrl, new FakeOptionsMonitor<SwitchboardOptions>(opts),
            Microsoft.Extensions.Logging.Abstractions.NullLogger<OllamaPriorityService>.Instance);
    }

    [Test]
    public async Task Lowers_local_ollama_when_enabled()
    {
        var ctrl = new FakeProcessController { Found = [111, 222] };
        var svc = Build(ctrl, enabled: true, ollamaUrl: "http://localhost:11434");

        svc.ApplyOnce();

        await Assert.That(ctrl.LoweredPids).Contains(111);
        await Assert.That(ctrl.LoweredPids).Contains(222);
    }

    [Test]
    public async Task Skips_when_disabled()
    {
        var ctrl = new FakeProcessController { Found = [111] };
        var svc = Build(ctrl, enabled: false, ollamaUrl: "http://localhost:11434");

        svc.ApplyOnce();

        await Assert.That(ctrl.LoweredPids).IsEmpty();
    }

    [Test]
    public async Task Skips_when_ollama_remote()
    {
        var ctrl = new FakeProcessController { Found = [111] };
        var svc = Build(ctrl, enabled: true, ollamaUrl: "http://gpu-box.intern:11434");

        svc.ApplyOnce();

        await Assert.That(ctrl.LoweredPids).IsEmpty();
    }
}
```

- [ ] **Step 2: Run → COMPILE FAIL.** `dotnet test`.

- [ ] **Step 3: Implement**

Create `Resources/OllamaPriorityService.cs`:

```csharp
namespace K.Switchboard.Resources;

using System.Runtime.InteropServices;
using Microsoft.Extensions.Hosting;

/// <summary>
/// Senkt beim Start die Priorität des lokalen Ollama-Prozesses auf below-normal (Maschinen-Schutz),
/// wenn <see cref="ResourceGateOptions.LowerOllamaPriority"/> aktiv ist und Ollama lokal läuft.
/// Best-effort, einmalig beim Start. macOS nicht unterstützt. Siehe Spec §2.
/// </summary>
public sealed class OllamaPriorityService(
    IProcessController processController,
    IOptionsMonitor<SwitchboardOptions> options,
    ILogger<OllamaPriorityService> logger) : IHostedService
{
    public Task StartAsync(CancellationToken cancellationToken)
    {
        ApplyOnce();
        return Task.CompletedTask;
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;

    /// <summary>Kern-Logik (testbar): Priorität einmalig anwenden, sofern Vorbedingungen erfüllt.</summary>
    public void ApplyOnce()
    {
        var opts = options.CurrentValue;
        if (!opts.ResourceGate.LowerOllamaPriority)
            return;

        if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
        {
            logger.LogInformation("Ollama-Priorität: macOS nicht unterstützt — übersprungen.");
            return;
        }

        if (!IsLocalHost(opts.OllamaBaseUrl))
        {
            logger.LogInformation(
                "Ollama-Priorität: OllamaBaseUrl '{Url}' ist nicht localhost — Priorität nicht beeinflussbar.",
                opts.OllamaBaseUrl);
            return;
        }

        var pids = processController.FindByName("ollama");
        if (pids.Count == 0)
        {
            logger.LogWarning("Ollama-Priorität: kein 'ollama'-Prozess gefunden.");
            return;
        }

        foreach (var pid in pids)
        {
            if (processController.TrySetBelowNormal(pid))
                logger.LogInformation("Ollama-Priorität: PID {Pid} auf below-normal gesetzt.", pid);
            else
                logger.LogWarning("Ollama-Priorität: PID {Pid} konnte nicht gesetzt werden (Rechte?).", pid);
        }
    }

    private static bool IsLocalHost(string baseUrl)
    {
        if (!Uri.TryCreate(baseUrl, UriKind.Absolute, out var uri))
            return false;
        var host = uri.Host;
        return host.Equals("localhost", StringComparison.OrdinalIgnoreCase)
            || host == "127.0.0.1"
            || host == "::1"
            || host == "[::1]";
    }
}
```

- [ ] **Step 4: Run → PASS** (3 Tests). `dotnet test`; `dotnet format K.Switchboard.slnx`.

- [ ] **Step 5: Commit**

`feat(switchboard): ollama-prozess-priorität beim start (opt-in)` — bullet body (HostedService ApplyOnce; localhost-only + opt-in + macOS-skip; below-normal via IProcessController; best-effort logging) + `Ref #268`. Stage Service + Testdatei.

---

## Task 4: LocalInferenceStats + LocalStatsStore (learned-stats.json)

**Files:**
- Create: `k.switchboard.net/src/K.Switchboard/Resources/LocalInferenceStats.cs`
- Create: `k.switchboard.net/src/K.Switchboard/Resources/ILocalStatsStore.cs`
- Create: `k.switchboard.net/src/K.Switchboard/Resources/LocalStatsStore.cs`
- Modify: `k.switchboard.net/src/K.Switchboard/SwitchboardJsonContext.cs`
- Modify: `.gitignore` (Repo-Root)
- Test: `k.switchboard.net/tests/K.Switchboard.Tests/Resources/LocalStatsStoreTests.cs`

- [ ] **Step 1: Define the record + register for JSON**

Create `Resources/LocalInferenceStats.cs`:

```csharp
namespace K.Switchboard.Resources;

/// <summary>Aggregierte Live-Telemetrie eines lokalen Modells (read-only Beobachtung). Siehe Spec §3.</summary>
public sealed record LocalInferenceStats
{
    /// <summary>Anzahl erfasster Inferenzen.</summary>
    public int Count { get; init; }

    /// <summary>Letzte gemessene End-to-End-Latenz (ms).</summary>
    public long LastLatencyMs { get; init; }

    /// <summary>Laufender Mittelwert der Latenz (ms).</summary>
    public double AvgLatencyMs { get; init; }

    /// <summary>Maximale gemessene Latenz (ms).</summary>
    public long MaxLatencyMs { get; init; }

    /// <summary>Letztes RAM-Delta (MB, 2-Punkt-GC-Approximation).</summary>
    public int LastRamDeltaMb { get; init; }

    /// <summary>Zuletzt gemeldete Modellgröße (MB) oder 0.</summary>
    public int LastSizeMb { get; init; }

    /// <summary>UTC-Zeitpunkt der letzten Aktualisierung.</summary>
    public DateTimeOffset UpdatedOn { get; init; }
}
```

In `SwitchboardJsonContext.cs` ergänzen (nach den bestehenden `[JsonSerializable]`-Zeilen):

```csharp
[JsonSerializable(typeof(Dictionary<string, K.Switchboard.Resources.LocalInferenceStats>))]
```

In `.gitignore` (Repo-Root) ergänzen:

```gitignore
# K.Switchboard per-install Live-Telemetrie (maschinenspezifisch, nie committen)
learned-stats.json
```

- [ ] **Step 2: Write the failing test**

Create `LocalStatsStoreTests.cs` (Persistenz-Roundtrip + Aggregation; test-ctor mit temp-dir analog `HardwareProfileCacheTests`):

```csharp
namespace K.Switchboard.Tests.Resources;

using K.Switchboard.Resources;

public sealed class LocalStatsStoreTests
{
    private static string FreshDir()
    {
        var d = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
        Directory.CreateDirectory(d);
        return d;
    }

    [Test]
    public async Task Record_aggregates_count_avg_max()
    {
        var dir = FreshDir();
        var store = new LocalStatsStore(dir,
            Microsoft.Extensions.Logging.Abstractions.NullLogger<LocalStatsStore>.Instance);

        store.Record("qwen2.5-coder:14b", elapsedMs: 100, ramDeltaMb: 9000, sizeMb: 9000);
        store.Record("qwen2.5-coder:14b", elapsedMs: 300, ramDeltaMb: 9100, sizeMb: 9000);

        var s = store.Get("qwen2.5-coder:14b")!;
        await Assert.That(s.Count).IsEqualTo(2);
        await Assert.That(s.MaxLatencyMs).IsEqualTo(300);
        await Assert.That(s.LastLatencyMs).IsEqualTo(300);
        await Assert.That(s.AvgLatencyMs).IsEqualTo(200.0);   // (100+300)/2
    }

    [Test]
    public async Task Persists_across_instances()
    {
        var dir = FreshDir();
        var store1 = new LocalStatsStore(dir,
            Microsoft.Extensions.Logging.Abstractions.NullLogger<LocalStatsStore>.Instance);
        store1.Record("llama3.2:3b", elapsedMs: 50, ramDeltaMb: 4000, sizeMb: 3900);

        var store2 = new LocalStatsStore(dir,
            Microsoft.Extensions.Logging.Abstractions.NullLogger<LocalStatsStore>.Instance);
        var s = store2.Get("llama3.2:3b")!;
        await Assert.That(s.Count).IsEqualTo(1);
        await Assert.That(s.LastSizeMb).IsEqualTo(3900);
    }
}
```

- [ ] **Step 3: Implement ILocalStatsStore + LocalStatsStore**

Create `Resources/ILocalStatsStore.cs`:

```csharp
namespace K.Switchboard.Resources;

/// <summary>Persistiert read-only Live-Telemetrie pro lokalem Modell (learned-stats.json).</summary>
public interface ILocalStatsStore
{
    /// <summary>Erfasst eine Inferenz-Messung und aktualisiert die Aggregation.</summary>
    void Record(string model, long elapsedMs, int ramDeltaMb, int sizeMb);

    /// <summary>Aktuelle Aggregation eines Modells oder null.</summary>
    LocalInferenceStats? Get(string model);
}
```

Create `Resources/LocalStatsStore.cs`:

```csharp
namespace K.Switchboard.Resources;

using System.Text.Json;

/// <summary>
/// Read-only Telemetrie-Store: aggregiert Live-Messungen pro Modell in <c>learned-stats.json</c>
/// (Per-Install, ApplicationData, NICHT committed). Beeinflusst die Admission NICHT. Siehe Spec §3.
/// </summary>
public sealed class LocalStatsStore : ILocalStatsStore
{
    private readonly string _filePath;
    private readonly ILogger<LocalStatsStore> _logger;
    private readonly SemaphoreSlim _lock = new(1, 1);
    private Dictionary<string, LocalInferenceStats>? _cache;

    /// <summary>Produktiver ctor: %APPDATA%/K.Switchboard.</summary>
    public LocalStatsStore(ILogger<LocalStatsStore> logger)
        : this(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "K.Switchboard"), logger)
    { }

    /// <summary>Test-ctor mit explizitem Verzeichnis.</summary>
    public LocalStatsStore(string directory, ILogger<LocalStatsStore> logger)
    {
        Directory.CreateDirectory(directory);
        _filePath = Path.Combine(directory, "learned-stats.json");
        _logger = logger;
    }

    public LocalInferenceStats? Get(string model)
    {
        _lock.Wait();
        try
        {
            return Load().TryGetValue(model, out var s) ? s : null;
        }
        finally { _lock.Release(); }
    }

    public void Record(string model, long elapsedMs, int ramDeltaMb, int sizeMb)
    {
        _lock.Wait();
        try
        {
            var map = Load();
            map.TryGetValue(model, out var prev);
            var count = (prev?.Count ?? 0) + 1;
            var avg = prev is null ? elapsedMs : (prev.AvgLatencyMs * prev.Count + elapsedMs) / count;
            map[model] = new LocalInferenceStats
            {
                Count = count,
                LastLatencyMs = elapsedMs,
                AvgLatencyMs = avg,
                MaxLatencyMs = Math.Max(prev?.MaxLatencyMs ?? 0, elapsedMs),
                LastRamDeltaMb = ramDeltaMb,
                LastSizeMb = sizeMb,
                UpdatedOn = DateTimeOffset.UtcNow
            };
            Save(map);
            _logger.LogInformation(
                "Live-Telemetrie {Model}: {Ms}ms, ramΔ {Ram}MB, size {Size}MB (n={Count})",
                model, elapsedMs, ramDeltaMb, sizeMb, count);
        }
        finally { _lock.Release(); }
    }

    private Dictionary<string, LocalInferenceStats> Load()
    {
        if (_cache is not null) return _cache;
        try
        {
            if (File.Exists(_filePath))
            {
                var json = File.ReadAllText(_filePath);
                _cache = JsonSerializer.Deserialize(json, SwitchboardJsonContext.Default.DictionaryStringLocalInferenceStats)
                         ?? new();
            }
            else
            {
                _cache = new();
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "learned-stats.json unlesbar — starte mit leerem Store.");
            _cache = new();
        }
        return _cache;
    }

    private void Save(Dictionary<string, LocalInferenceStats> map)
    {
        try
        {
            var json = JsonSerializer.Serialize(map, SwitchboardJsonContext.Default.DictionaryStringLocalInferenceStats);
            File.WriteAllText(_filePath, json);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "learned-stats.json konnte nicht geschrieben werden ({Path}).", _filePath);
        }
    }
}
```

> **JSON-Context-Property-Name:** Der source-gen-Name für `Dictionary<string, LocalInferenceStats>` ist i.d.R. `DictionaryStringLocalInferenceStats`. Falls der Compiler einen anderen Namen generiert (Build-Fehler), den tatsächlich generierten Property-Namen aus `SwitchboardJsonContext` verwenden (IntelliSense/Build-Meldung).

- [ ] **Step 4: Run → PASS** (2 Tests). `dotnet build` (0 Warnings). `dotnet test`. `dotnet format K.Switchboard.slnx`.

- [ ] **Step 5: Commit**

`feat(switchboard): LocalStatsStore` → LOWERCASE: `feat(switchboard): local-stats-store (learned-stats.json)` — bullet body (LocalInferenceStats-record + JSON-context; ILocalStatsStore+LocalStatsStore aggregiert count/avg/max, SemaphoreSlim, per-install; .gitignore) + `Ref #268`. Stage neue Quell-Dateien + SwitchboardJsonContext.cs + .gitignore + Testdatei.

---

## Task 5: OllamaProvider-Telemetrie + DI-Verdrahtung

**Files:**
- Modify: `k.switchboard.net/src/K.Switchboard/Providers/OllamaProvider.cs`
- Modify: `k.switchboard.net/src/K.Switchboard/Program.cs` (DI)
- Modify: `k.switchboard.net/tests/K.Switchboard.Tests/Providers/ProviderForwardingTests.cs` (ctor-Anpassung + Telemetrie-Test)

> `OllamaProvider` bekommt `ILocalStatsStore` injiziert. Wenn `RecordLocalInferenceStats` aktiv: Stopwatch + 2-Punkt-GC um den Inferenz-Block; bei erfolgreichem Call `Record(resolvedModel, elapsedMs, ramDeltaMb, 0)`. `sizeMb=0` (die `/api/ps`-Größe wird im Hot-Path bewusst NICHT abgefragt — kein Extra-HTTP-Call; Spec §6).

- [ ] **Step 1: Add ctor dep + telemetry test**

In `ProviderForwardingTests.cs`: der `CreateOllamaProvider`-Helper (bzw. die `new OllamaProvider(...)`-Aufrufe) bekommt den neuen `ILocalStatsStore`-Parameter. Füge einen Fake + Telemetrie-Test hinzu:

```csharp
    private sealed class FakeStatsStore : K.Switchboard.Resources.ILocalStatsStore
    {
        public List<(string Model, long Ms)> Records { get; } = [];
        public void Record(string model, long elapsedMs, int ramDeltaMb, int sizeMb) => Records.Add((model, elapsedMs));
        public K.Switchboard.Resources.LocalInferenceStats? Get(string model) => null;
    }

    [Test]
    public async Task Ollama_records_telemetry_when_enabled()
    {
        var stats = new FakeStatsStore();
        // Baue einen OllamaProvider mit RecordLocalInferenceStats=true + erfolgreichem Stub-Ollama-Response.
        // (Nutze das bestehende Setup-Muster dieser Testklasse: MockHttpHandler liefert 200 + minimal-JSON,
        //  SingleClientFactory, FakeOptionsMonitor mit ResourceGate.RecordLocalInferenceStats=true,
        //  new LocalInferenceGate(), und stats als ILocalStatsStore.)
        // ... Provider.ForwardAsync(ctx, "qwen2.5-coder:14b", ct) ...

        await Assert.That(stats.Records.Count).IsEqualTo(1);
        await Assert.That(stats.Records[0].Model).IsEqualTo("qwen2.5-coder:14b");
    }
```

> Der ausführende Subagent: Lies das bestehende `ProviderForwardingTests`-Setup für OllamaProvider (wie der Provider dort konstruiert + aufgerufen wird, wie der Mock-Response aussieht) und baue den Telemetrie-Test nach DIESEM Muster. Ergänze einen Gegentest `Ollama_does_not_record_when_disabled` (RecordLocalInferenceStats=false → `stats.Records` leer). Alle bestehenden OllamaProvider-Tests bekommen den neuen ctor-Parameter (`new FakeStatsStore()` oder ein no-op-Fake).

- [ ] **Step 2: Run → COMPILE FAIL** (ctor-Signatur + ILocalStatsStore). `dotnet test`.

- [ ] **Step 3: Add ctor dep + telemetry to OllamaProvider**

In `OllamaProvider.cs`: den primary-ctor um `ILocalStatsStore statsStore` erweitern:

```csharp
public sealed class OllamaProvider(
    IHttpClientFactory httpClientFactory,
    IOptionsMonitor<SwitchboardOptions> options,
    ILogger<OllamaProvider> logger,
    LocalInferenceGate localGate,
    ILocalStatsStore statsStore) : IProvider
```

Den Inferenz-Block in `ForwardAsync` (ab `using var _ = await localGate.AcquireAsync(...)` bis zum Methodenende) mit Telemetrie umschließen. Ersetze den Block (aktuell Zeilen ~45–61) durch:

```csharp
        var recordStats = opts.ResourceGate.RecordLocalInferenceStats;
        var sw = recordStats ? System.Diagnostics.Stopwatch.StartNew() : null;
        var preFreeMb = recordStats ? FreeRamMb() : 0;
        var success = false;
        try
        {
            using var _ = await localGate.AcquireAsync(cancellationToken);
            using var response = await client.SendAsync(
                upstreamRequest, HttpCompletionOption.ResponseHeadersRead, cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                await CopyRawResponseAsync(context, response, cancellationToken);
                return;
            }

            success = true;
            if (isStreaming)
                await WriteStreamingAnthropicResponseAsync(context, response, resolvedModel, cancellationToken);
            else
                await WriteJsonAnthropicResponseAsync(context, response, cancellationToken);
        }
        finally
        {
            if (recordStats && success && sw is not null)
            {
                sw.Stop();
                var ramDeltaMb = Math.Max(0, preFreeMb - FreeRamMb());
                statsStore.Record(resolvedModel, sw.ElapsedMilliseconds, ramDeltaMb, 0);
            }
        }
```

Und eine private Helper am Klassenende ergänzen (gleiche GC-Formel wie `LiveResourceProbe`):

```csharp
    /// <summary>Aktuell freier System-RAM in MB (GC-MemoryInfo, billig — wie LiveResourceProbe).</summary>
    private static int FreeRamMb()
    {
        var info = GC.GetGCMemoryInfo();
        return (int)(Math.Max(0, info.TotalAvailableMemoryBytes - info.MemoryLoadBytes) / (1024 * 1024));
    }
```

(Die bestehende `if (isStreaming) { ... return; } await WriteJson...`-Struktur geht im try-Block auf; die early-returns lösen das finally aus.)

- [ ] **Step 4: DI in Program.cs**

In der ResourceGate-DI-Region (wo `ResourceGate` etc. registriert sind) ergänzen:

```csharp
    builder.Services.AddSingleton<K.Switchboard.Resources.IProcessController, K.Switchboard.Resources.ProcessController>();
    builder.Services.AddSingleton<K.Switchboard.Resources.ILocalStatsStore, K.Switchboard.Resources.LocalStatsStore>();
    builder.Services.AddHostedService<K.Switchboard.Resources.OllamaPriorityService>();
```

(Kurznamen, falls `using K.Switchboard.Resources;` vorhanden. `LocalStatsStore` resolved den produktiven 1-arg-ctor `(ILogger)`. `OllamaPriorityService` braucht `IProcessController` + Options + Logger — alle registriert.)

- [ ] **Step 5: Run all tests → PASS** (107 + neue; alle OllamaProvider-Tests mit neuem ctor-Param grün). `dotnet build` (0 Warnings). `dotnet test`. `dotnet format K.Switchboard.slnx`.

- [ ] **Step 6: Commit**

`feat(switchboard): live-telemetrie im OllamaProvider + DI` → LOWERCASE: `feat(switchboard): live-telemetrie im OllamaProvider + DI` (erstes Wort `live` klein ✓) — bullet body (OllamaProvider misst latenz via stopwatch + ramDelta via 2-punkt-GC, Record bei erfolg wenn opt-in; sizeMb=0 kein extra /api/ps-call; DI: IProcessController + LocalStatsStore + OllamaPriorityService-hostedservice) + `Ref #268`. Stage OllamaProvider.cs + Program.cs + ProviderForwardingTests.cs.

---

## Task 6: Dokumentation

**Files:**
- Modify: `k.switchboard.net/docs/configuration.md`, `troubleshooting.md`, `resource-aware-routing.md`, `eval-measurement.md`

- [ ] **Step 1: configuration.md**

In der ResourceGate-Optionen-Sektion die zwei neuen Flags ergänzen: `LowerOllamaPriority` (bool, Default false — opt-in; senkt lokalen Ollama-Prozess beim Start auf below-normal; nur localhost; macOS nicht unterstützt) und `RecordLocalInferenceStats` (bool, Default false — opt-in; erfasst Live-Telemetrie in `learned-stats.json`; **read-only, ändert die Admission NICHT**). Neue Unter-Sektion `learned-stats.json` (Ort per-OS wie hw-profile.json aber macOS nicht unterstützt, per-install, nicht committed, Felder Count/AvgLatencyMs/MaxLatencyMs/LastRamDeltaMb/LastSizeMb/UpdatedOn, Zweck: manuelle Mapping-Pflege). JSON-Beispiel um beide Flags ergänzen.

- [ ] **Step 2: troubleshooting.md**

Einträge: „Ollama-Priorität wird nicht gesenkt" (Flag aus / OllamaBaseUrl nicht localhost / fehlende Rechte / Ollama nach K.Switchboard-Start neu gestartet → Neustart von K.Switchboard); „learned-stats.json / Telemetrie deaktivieren" (`RecordLocalInferenceStats: false`).

- [ ] **Step 3: resource-aware-routing.md**

Im Blast-Radius-/Maschinen-Schutz-Abschnitt die Ollama-Prozess-Priorität als dritten Schutzmechanismus ergänzen (neben num_thread + Serialisierung). Eine kurze Sektion „Live-Telemetrie (read-only)" ergänzen: beobachtet Latenz/RAM-Delta, schreibt learned-stats.json, **beeinflusst den Datenfluss/die Admission NICHT** — reine Beobachtung für die Mapping-Pflege.

- [ ] **Step 4: eval-measurement.md**

Sektion: `learned-stats.json` als Live-Betriebs-Datenquelle (ergänzend zu den dedizierten Eval-Läufen) für die manuelle Verfeinerung der committed `ModelValidation`-Werte (`LatencyP50Ms` aus `AvgLatencyMs`/Live-Latenzen; `PeakRamMb` als Plausibilitätscheck via `LastRamDeltaMb`). Klarstellen: Live-Telemetrie ist Approximation, dedizierte Eval-Läufe bleiben die präzise Quelle.

- [ ] **Step 5: Commit**

`docs(switchboard): prozess-priorität + live-telemetrie dokumentiert` — bullet body (configuration: LowerOllamaPriority + RecordLocalInferenceStats + learned-stats.json; troubleshooting: priorität/telemetrie-gründe; resource-aware-routing: priorität als blast-radius + telemetrie read-only; eval-measurement: learned-stats als live-quelle) + `Ref #268`. Stage die 4 Docs.

---

## Self-Review

**Spec-Coverage (§-für-§):**
- §2 Prozess-Priorität → Task 2 (IProcessController) + Task 3 (OllamaPriorityService) ✓
- §3 Live-Telemetrie → Task 4 (LocalStatsStore) + Task 5 (OllamaProvider-Messung) ✓
- §4 DI → Task 5 Step 4 ✓ · §5 CreateDefault-Defaults → Task 1 ✓
- §6 Tests → in jeder Task ✓ · §7 Docs → Task 6 ✓
- §8 Akzeptanzkriterien: alle abgedeckt. macOS durchgehend ausgeschlossen; Telemetrie read-only.

**Type-Konsistenz:** `ILocalStatsStore.Record(string, long, int, int)` + `Get(string)`; `LocalInferenceStats{Count,LastLatencyMs,AvgLatencyMs,MaxLatencyMs,LastRamDeltaMb,LastSizeMb,UpdatedOn}`; `IProcessController.{FindByName(string)→IReadOnlyList<int>, TrySetBelowNormal(int)→bool}`; `OllamaPriorityService.ApplyOnce()`; `ResourceGateOptions.{LowerOllamaPriority,RecordLocalInferenceStats}` — task-übergreifend konsistent. OllamaProvider-ctor-Erweiterung (Task 5) bricht bestehende Provider-Tests → in Task 5 Step 1 angepasst.

**Abhängigkeiten:** Task 1→2→3 (Priorität), Task 4→5 (Telemetrie); Task 5 verdrahtet DI für alle. Reihenfolge 1..6.

**Offen/bewusst:** `sizeMb=0` in der Telemetrie (kein Extra-/api/ps-Call im Hot-Path; Feld bleibt für Zukunft). `ramDeltaMb` ist systemweite GC-Approximation (dokumentiert). Prozess-Priorität nur localhost + einmal beim Start. Telemetrie read-only (kein Drift). macOS nicht unterstützt.

---

## Execution Handoff

**Plan gespeichert unter `docs/superpowers/plans/2026-06-09-resource-aware-routing-plus2.md`.** Umsetzung via `superpowers:subagent-driven-development` (CLAUDE.md-Vorgabe) — frischer Subagent pro Task, Spec+Quality-Review zwischen den Tasks. Branch `feature/268-resource-gate-plus2`, kein Push ohne Auftrag, `dotnet format` + Train-Check vor Push. Nach +2-Merge ist #268 vollständig → Train Richtung Freeze→Beta→Stable.

# ResourceGate Ausbau +1 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Den MVP-`ResourceGate` um GPU-Pfad (VRAM-Admission gegen statisches VRAM minus Display-Reserve, AMD via rocm-smi), ein Latenz-Hard-Gate (warm/cold × Kontextlänge, Opt-in) und einen Windows-CPU-Last-Sampler (`GetSystemTimes`) erweitern.

**Architecture:** Additiv auf dem gemergten MVP. Neue Config-Felder in `ModelValidation`/`ResourceGateOptions`; GPU-Pfad + Latenz-Check als zusätzliche Zweige in `ResourceGate.EvaluateAsync` (Signatur bekommt `inputTokens`); `HardwareProfileDetector` lernt `rocm-smi`; `CpuLoadSampler` lernt Windows via source-generated P/Invoke. macOS wird NICHT unterstützt.

**Tech Stack:** C# / .NET 10, ASP.NET Core Minimal API, `IOptionsMonitor`, source-generated JSON, `LibraryImport` (trim/AOT-safe P/Invoke), TUnit.

**Spec:** [docs/superpowers/specs/2026-06-07-resource-aware-routing-plus1-design.md](../specs/2026-06-07-resource-aware-routing-plus1-design.md)

**Basis:** MVP ist gemergt (Alpha `v1.21.0-alpha1`); 91 Tests grün. Diese Stufe erweitert ihn — alle 91 müssen grün bleiben.

---

## Konventionen (für jeden ausführenden Subagenten)

- Repo-Root `c:\Users\gkump\source\repos\1d70f\K.Agents`. Switchboard: `k.switchboard.net/src/K.Switchboard/`, Tests: `k.switchboard.net/tests/K.Switchboard.Tests/`.
- ALREADY auf Branch `feature/268-resource-gate-plus1` — NICHT wechseln/pushen.
- Build/Test aus `k.switchboard.net/`: `dotnet build` · `dotnet test` (TUnit ignoriert `--filter` → ganze Suite läuft).
- **VOR jedem Commit-Schritt, der C# ändert:** `dotnet format K.Switchboard.slnx` aus `k.switchboard.net/` laufen lassen (CI-Gate `dotnet format --verify-no-changes`; NICHT in build/test enthalten). Keine kompakten Multi-Initializer-Zeilen.
- TUnit: `[Test] public async Task`, `await Assert.That(x).IsEqualTo(y)`. AOT: standalone-serialisierte Typen in `SwitchboardJsonContext` registrieren; Test-Projekt hat `JsonSerializerIsReflectionEnabledByDefault=false` → test-lokale source-gen-Contexts nutzen.
- German XML-doc, English identifiers. **Commit:** `type(scope): description` — Description LOWERCASE erstes Wort (CI `commit-msg.ps1` prüft `^[A-Z]` → FAIL; gilt auch für Akronyme: `gpu`, `vram`, `rocm`, `cpu`), Bulletpoint-Body, Footer `Ref #268` (KEIN Closes). Scope `switchboard`.
- Kein Push (Push/PR erst auf Auftrag, mit Train-Check).

## File Structure

| Datei | Änderung |
|---|---|
| `SwitchboardOptions.cs` | `ModelValidation.PeakVramMb`; `ResourceGateOptions`: `VramDisplayReserveMb`, `MaxLatencyMs`, `ColdLatencyFactor`, `LatencyContextReferenceTokens`; `CreateDefault()`-Defaults. |
| `Resources/HardwareProfileDetector.cs` | `rocm-smi`-Zweig (AMD) zwischen nvidia-smi und wmic. |
| `Resources/CpuLoadSampler.cs` | Windows-Zweig via `GetSystemTimes` (`LibraryImport`); Klasse wird `partial`. |
| `Resources/ResourceGate.cs` | `EvaluateAsync`-Signatur `+ int inputTokens`; GPU-VRAM-Admission-Pfad; Latenz-Gate. |
| `Program.cs` | Endpoint: grobe Input-Token-Schätzung aus Request-Body → `EvaluateAsync(requestedModel, inputTokens, ct)`. |
| Tests `Resources/` | neue Tests (VRAM-Admission, Latenz-Gate, rocm-smi, Windows-CPU-Sampler); MVP-Tests an Signatur anpassen. |
| `docs/*` | configuration/troubleshooting/resource-aware-routing/eval-measurement; macOS als nicht unterstützt markieren. |

---

## Task 1: Config-Felder (+ CreateDefault-Defaults)

**Files:**
- Modify: `k.switchboard.net/src/K.Switchboard/SwitchboardOptions.cs`
- Test: `k.switchboard.net/tests/K.Switchboard.Tests/Resources/SwitchboardOptionsPlus1Tests.cs`

- [ ] **Step 1: Write the failing test**

Create `tests/K.Switchboard.Tests/Resources/SwitchboardOptionsPlus1Tests.cs`:

```csharp
namespace K.Switchboard.Tests.Resources;

public sealed class SwitchboardOptionsPlus1Tests
{
    [Test]
    public async Task CreateDefault_has_plus1_resourcegate_defaults()
    {
        var opts = SwitchboardOptions.CreateDefault();

        await Assert.That(opts.ResourceGate.VramDisplayReserveMb).IsEqualTo(2048);
        await Assert.That(opts.ResourceGate.MaxLatencyMs).IsEqualTo(0);
        await Assert.That(opts.ResourceGate.ColdLatencyFactor).IsEqualTo(2.0);
        await Assert.That(opts.ResourceGate.LatencyContextReferenceTokens).IsEqualTo(4000);
    }

    [Test]
    public async Task ModelValidation_has_peak_vram()
    {
        var v = new ModelValidation { PeakRamMb = 11000, PeakVramMb = 9000 };
        await Assert.That(v.PeakVramMb).IsEqualTo(9000);
    }
}
```

- [ ] **Step 2: Run test → COMPILE FAIL** (`VramDisplayReserveMb` etc. fehlen). Run: `dotnet test`.

- [ ] **Step 3: Add fields**

In `SwitchboardOptions.cs`, im `ModelValidation`-record nach `PeakRamMb` ergänzen:

```csharp
    /// <summary>Beobachteter Peak-VRAM (MB) beim Laden auf der GPU.
    /// 0 = nicht GPU-validiert → kein GPU-Pfad für dieses Modell (CPU-Admission gilt).</summary>
    public int PeakVramMb { get; init; }
```

Im `ResourceGateOptions`-record nach `CpuMaxLoadPercent` ergänzen:

```csharp
    /// <summary>VRAM-Reserve (MB) für Display/Compositor, die NICHT für lokale Inferenz zählt.
    /// GPU-Admission: PeakVramMb ≤ (Gesamt-VRAM − Reserve). Headless-Server → 0.</summary>
    public int VramDisplayReserveMb { get; init; } = 2048;

    /// <summary>Latenz-Schwelle (ms): erwartete lokale Latenz darüber → substituieren.
    /// 0 = Latenz-Gate aus (Opt-in, backward-safe).</summary>
    public int MaxLatencyMs { get; init; }

    /// <summary>Faktor für Cold-Load-Latenz (Modell nicht warm): erwartete Latenz = P50 × Faktor.</summary>
    public double ColdLatencyFactor { get; init; } = 2.0;

    /// <summary>Referenz-Kontextlänge (Tokens) für die Latenz-Skalierung (≈ reales Headless-Payload).</summary>
    public int LatencyContextReferenceTokens { get; init; } = 4000;
```

In `CreateDefault()` den `ResourceGate`-Initializer um die neuen Felder ergänzen (Defaults sind bereits die record-Defaults; explizit setzen für Klarheit in der ausgelieferten config.json):

```csharp
        ResourceGate = new ResourceGateOptions
        {
            Enabled = true,
            RamBufferMb = 0,
            CpuLoadWindowSeconds = 4,
            CpuMaxLoadPercent = 85,
            VramDisplayReserveMb = 2048,
            MaxLatencyMs = 0,
            ColdLatencyFactor = 2.0,
            LatencyContextReferenceTokens = 4000
        },
```

- [ ] **Step 4: Run test → PASS.** Run `dotnet test`. Dann `dotnet format K.Switchboard.slnx`.

- [ ] **Step 5: Commit**

`feat(switchboard): config-felder für GPU-pfad + latenz-gate` — bullet body (ModelValidation.PeakVramMb; ResourceGateOptions vram-reserve/max-latency/cold-faktor/kontext-referenz; CreateDefault-defaults) + `Ref #268`. Stage SwitchboardOptions.cs + Testdatei.

---

## Task 2: AMD-VRAM via rocm-smi (Detektor)

**Files:**
- Modify: `k.switchboard.net/src/K.Switchboard/Resources/HardwareProfileDetector.cs`
- Test: `k.switchboard.net/tests/K.Switchboard.Tests/Resources/HardwareProfileDetectorAmdTests.cs`

- [ ] **Step 1: Write the failing test**

Create `tests/K.Switchboard.Tests/Resources/HardwareProfileDetectorAmdTests.cs`:

```csharp
namespace K.Switchboard.Tests.Resources;

using K.Switchboard.Resources;

public sealed class HardwareProfileDetectorAmdTests
{
    private sealed class FakeProcessRunner(Dictionary<string, (int Exit, string Out)> map) : IProcessRunner
    {
        public Task<(int ExitCode, string StdOut)> RunAsync(string file, string args, CancellationToken ct)
            => Task.FromResult(map.TryGetValue(file, out var r) ? (r.Exit, r.Out) : (1, string.Empty));
    }

    [Test]
    public async Task Detects_amd_gpu_from_rocm_smi_when_no_nvidia()
    {
        // nvidia-smi fehlt (Exit 1), rocm-smi liefert VRAM-Total in Bytes (CSV).
        var runner = new FakeProcessRunner(new()
        {
            ["rocm-smi"] = (0, "device,VRAM Total Memory (B)\ncard0,17163091968\n")
        });
        var detector = new HardwareProfileDetector(runner,
            Microsoft.Extensions.Logging.Abstractions.NullLogger<HardwareProfileDetector>.Instance);

        var profile = await detector.DetectAsync(CancellationToken.None);

        await Assert.That(profile.GpuVendor).IsEqualTo("AMD");
        await Assert.That(profile.VramMb).IsEqualTo(16368);   // 17163091968 / 1024 / 1024
    }
}
```

- [ ] **Step 2: Run → COMPILE/TEST FAIL** (rocm-smi nicht erkannt → GpuVendor "none"). Run `dotnet test`.

- [ ] **Step 3: Add rocm-smi branch**

In `HardwareProfileDetector.cs`, `DetectGpuAsync`, NACH dem nvidia-smi-Block (nach Zeile ~47, vor dem Windows-wmic-Block) einfügen:

```csharp
        // 2) AMD via rocm-smi (Linux + Windows, falls ROCm installiert)
        var (rexit, rout) = await runner.RunAsync("rocm-smi", "--showmeminfo vram --csv", ct);
        if (rexit == 0 && !string.IsNullOrWhiteSpace(rout))
        {
            // CSV: Header + Datenzeilen; eine Spalte enthält "VRAM Total Memory (B)" in Bytes.
            var lines = rout.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
            var header = lines.FirstOrDefault()?.Split(',', StringSplitOptions.TrimEntries) ?? [];
            var vramCol = Array.FindIndex(header, h => h.Contains("VRAM Total", StringComparison.OrdinalIgnoreCase));
            if (vramCol >= 0)
            {
                foreach (var dataLine in lines.Skip(1))
                {
                    var cols = dataLine.Split(',', StringSplitOptions.TrimEntries);
                    if (cols.Length > vramCol
                        && long.TryParse(cols[vramCol], NumberStyles.Integer, CultureInfo.InvariantCulture, out var bytes)
                        && bytes > 0)
                    {
                        return ("AMD", "amd-rocm-gpu", (int)(bytes / (1024 * 1024)));
                    }
                }
            }
        }
```

(Die Kommentar-Nummerierung der Folgeblöcke — Windows-wmic, macOS — auf 3)/4) hochziehen, damit die Reihenfolge stimmt.)

- [ ] **Step 4: Run test → PASS** (AMD erkannt; NVIDIA-Test aus dem MVP bleibt grün, da nvidia-smi-Pfad zuerst greift). `dotnet format K.Switchboard.slnx`.

- [ ] **Step 5: Commit**

`feat(switchboard): AMD-VRAM-detektion via rocm-smi` → LOWERCASE: `feat(switchboard): amd-VRAM-detektion via rocm-smi` — bullet body (rocm-smi --showmeminfo vram zwischen nvidia-smi und wmic; CSV-VRAM-spalte in MB; fehlt → fallback) + `Ref #268`.

---

## Task 3: CPU-Sampler Windows (GetSystemTimes)

**Files:**
- Modify: `k.switchboard.net/src/K.Switchboard/Resources/CpuLoadSampler.cs`
- Test: `k.switchboard.net/tests/K.Switchboard.Tests/Resources/CpuLoadSamplerTests.cs`

> Windows-CPU-Last via Win32 `GetSystemTimes` über `[LibraryImport]` (source-generated P/Invoke, trim/AOT-safe — NICHT `[DllImport]`). Linux bleibt `/proc/stat`. macOS/andere → 0.

- [ ] **Step 1: Write the failing/portable test**

Create `tests/K.Switchboard.Tests/Resources/CpuLoadSamplerTests.cs`. Der Test läuft real auf der CI-Plattform (win-x64 → Windows-Pfad; Linux → /proc/stat). Plattform-tolerant: Wert in [0,100].

```csharp
namespace K.Switchboard.Tests.Resources;

using K.Switchboard.Resources;

public sealed class CpuLoadSamplerTests
{
    [Test]
    public async Task SampleAsync_returns_value_in_valid_range()
    {
        var sampler = new CpuLoadSampler();
        var load = await sampler.SampleAsync(1, CancellationToken.None);

        await Assert.That(load).IsGreaterThanOrEqualTo(0.0);
        await Assert.That(load).IsLessThanOrEqualTo(100.0);
    }
}
```

(Dieser Test ist auf Linux/Windows grün — er verifiziert, dass der jeweilige Plattform-Pfad keinen Out-of-Range-Wert/Crash liefert. Der frühere MVP-Zustand (Linux-only) erfüllt ihn bereits; nach dem Windows-Zweig erfüllt ihn auch win-x64 mit echtem Wert statt 0.)

- [ ] **Step 2: Run → PASS schon (Range-Test); danach Windows-Zweig hinzufügen.** Run `dotnet test`.

- [ ] **Step 3: Replace CpuLoadSampler.cs**

Ersetze den kompletten Inhalt von `Resources/CpuLoadSampler.cs`:

```csharp
namespace K.Switchboard.Resources;

using System.Globalization;
using System.Runtime.InteropServices;

/// <summary>
/// System-CPU-Last (%): Linux via zwei /proc/stat-Snapshots, Windows via GetSystemTimes
/// (source-generated P/Invoke, trim-safe). macOS/andere liefern 0 (nicht unterstützt).
/// </summary>
public sealed partial class CpuLoadSampler : ICpuLoadSampler
{
    public async Task<double> SampleAsync(int windowSeconds, CancellationToken ct)
    {
        var sampleMs = Math.Min(Math.Clamp(windowSeconds, 1, 10) * 1000, 1000);

        if (RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
        {
            var (idle1, total1) = ReadProcStat();
            await Task.Delay(sampleMs, ct);
            var (idle2, total2) = ReadProcStat();
            return BusyPercent(total2 - total1, idle2 - idle1);
        }

        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            if (!TryReadWindowsTimes(out var idle1, out var total1)) return 0.0;
            await Task.Delay(sampleMs, ct);
            if (!TryReadWindowsTimes(out var idle2, out var total2)) return 0.0;
            return BusyPercent(total2 - total1, idle2 - idle1);
        }

        return 0.0;   // macOS/andere — nicht unterstützt
    }

    private static double BusyPercent(long totalDelta, long idleDelta)
        => totalDelta <= 0 ? 0.0 : Math.Clamp(100.0 * (totalDelta - idleDelta) / totalDelta, 0, 100);

    private static (long Idle, long Total) ReadProcStat()
    {
        try
        {
            var line = File.ReadLines("/proc/stat").FirstOrDefault(l => l.StartsWith("cpu ")) ?? string.Empty;
            var nums = line.Split(' ', StringSplitOptions.RemoveEmptyEntries).Skip(1)
                           .Select(s => long.TryParse(s, NumberStyles.Integer, CultureInfo.InvariantCulture, out var v) ? v : 0)
                           .ToArray();
            if (nums.Length < 5) return (0, 0);
            var idle = nums[3] + (nums.Length > 4 ? nums[4] : 0);   // idle + iowait
            var total = nums.Sum();
            return (idle, total);
        }
        catch
        {
            return (0, 0);
        }
    }

    private static bool TryReadWindowsTimes(out long idle, out long total)
    {
        idle = 0;
        total = 0;
        if (!GetSystemTimes(out var idleTime, out var kernelTime, out var userTime))
            return false;
        // Windows: kernelTime ENTHÄLT idleTime. total = kernel + user; busy = total − idle.
        idle = idleTime;
        total = kernelTime + userTime;
        return true;
    }

    [LibraryImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool GetSystemTimes(out long lpIdleTime, out long lpKernelTime, out long lpUserTime);
}
```

> `out long` ist layout-kompatibel mit `FILETIME` (8 Bytes / 64-bit 100ns-Ticks). Die Klasse MUSS `partial` sein (LibraryImport generiert den Marshalling-Code).

- [ ] **Step 4: Run test + build → PASS, 0 Warnings.** `dotnet test`; `dotnet build`. Dann `dotnet format K.Switchboard.slnx`.

- [ ] **Step 5: Commit**

`feat(switchboard): cpu-sampler Windows via GetSystemTimes` — bullet body (LibraryImport source-gen P/Invoke trim-safe; kernel enthält idle → total=kernel+user; Linux unverändert; macOS=0) + `Ref #268`.

---

## Task 4: ResourceGate GPU-Pfad + EvaluateAsync(inputTokens)

**Files:**
- Modify: `k.switchboard.net/src/K.Switchboard/Resources/ResourceGate.cs`
- Modify: `k.switchboard.net/tests/K.Switchboard.Tests/Resources/ResourceGateTests.cs` (Signatur-Anpassung + GPU-Tests)
- Modify: `k.switchboard.net/tests/K.Switchboard.Tests/Integration/ResourceGateEndpointTests.cs` (Signatur, falls dort direkt aufgerufen — sonst über Endpoint)

> Refactor: `EvaluateAsync` bekommt `int inputTokens` (für Task 5). Neuer GPU-Pfad (VRAM-Admission) parallel zum bestehenden CPU-Pfad (RAM-Admission). Probe wird einmal geholt; CPU-Last-Check gemeinsam. Latenz-Gate kommt in Task 5 an den markierten Einhängepunkt.

- [ ] **Step 1: Adapt MVP tests to the new signature + add GPU tests**

In `ResourceGateTests.cs`: ALLE Aufrufe `gate.EvaluateAsync("local-coder", CancellationToken.None)` ändern zu `gate.EvaluateAsync("local-coder", 0, CancellationToken.None)` (inputTokens=0 → Latenz-Gate ohnehin Opt-in/inaktiv → MVP-Verhalten unverändert).

Dann GPU-Tests ergänzen (am Ende der Klasse). Der `Build`-Helper nutzt ein NVIDIA-Profil (`Gpu14b`); für GPU-Admission braucht das Modell `PeakVramMb`. Neuer Helper + Tests:

```csharp
    private static ResourceGate BuildGpu(LiveResourceSnapshot snap, HardwareProfile profile, int peakVramMb, int vramReserveMb = 2048)
    {
        var opts = new SwitchboardOptions
        {
            ResourceGate = new ResourceGateOptions { Enabled = true, CpuMaxLoadPercent = 85, VramDisplayReserveMb = vramReserveMb },
            ModelAliases = new() { ["local-coder"] = "qwen2.5-coder:14b" },
            LocalModelTiers = new() { ["qwen2.5-coder:14b"] = "L" },
            TierSubstitutions = new() { ["L"] = "claude-sonnet-4-6" },
            HardwareClasses =
            [
                new()
                {
                    Name = "gpu-14b",
                    Match = new() { GpuVendor = "NVIDIA", MinVramMb = 10240 },
                    Models = new() { ["qwen2.5-coder:14b"] = new ModelValidation { PeakRamMb = 2000, PeakVramMb = peakVramMb, ValidatedOn = "rig" } }
                }
            ]
        };
        var optsMon = new FakeOptionsMonitor<SwitchboardOptions>(opts);
        var tmp = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
        Directory.CreateDirectory(tmp);
        var cache = new HardwareProfileCache(new FixedDetector(profile), tmp,
            Microsoft.Extensions.Logging.Abstractions.NullLogger<HardwareProfileCache>.Instance);
        return new ResourceGate(new ModelRouter(optsMon), cache, new HardwareClassifier(), new FakeProbe(snap), optsMon,
            Microsoft.Extensions.Logging.Abstractions.NullLogger<ResourceGate>.Instance);
    }

    private static readonly HardwareProfile NvidiaGpu16gb =
        new() { TotalRamMb = 32000, Cores = 16, GpuVendor = "NVIDIA", VramMb = 16384 };

    [Test]
    public async Task Gpu_admits_when_vram_sufficient_after_reserve()
    {
        // 16384 − 2048 = 14336 usable; Modell 9000 ≤ 14336 → Proceed (GPU).
        var gate = BuildGpu(new LiveResourceSnapshot { FreeRamMb = 1000, CpuLoadPercent = 10 }, NvidiaGpu16gb, peakVramMb: 9000);
        var d = await gate.EvaluateAsync("local-coder", 0, CancellationToken.None);
        await Assert.That(d.Action).IsEqualTo(RoutingAction.Proceed);
        await Assert.That(d.EffectiveModel).IsEqualTo("local-coder");   // lokal, trotz wenig freiem RAM (GPU-Pfad)
    }

    [Test]
    public async Task Gpu_substitutes_when_vram_below_reserve_adjusted_need()
    {
        // 16384 − 2048 = 14336 usable; Modell 15000 > 14336 → Substitution.
        var gate = BuildGpu(new LiveResourceSnapshot { FreeRamMb = 30000, CpuLoadPercent = 10 }, NvidiaGpu16gb, peakVramMb: 15000);
        var d = await gate.EvaluateAsync("local-coder", 0, CancellationToken.None);
        await Assert.That(d.EffectiveModel).IsEqualTo("claude-sonnet-4-6");
    }

    [Test]
    public async Task Cpu_path_used_when_model_has_no_peak_vram()
    {
        // GPU-Profil, aber Modell ohne PeakVramMb → CPU-Pfad (RAM-Admission). peakVramMb=0.
        var gate = BuildGpu(new LiveResourceSnapshot { FreeRamMb = 1000, CpuLoadPercent = 10 }, NvidiaGpu16gb, peakVramMb: 0);
        var d = await gate.EvaluateAsync("local-coder", 0, CancellationToken.None);
        // PeakRamMb=2000, buffer=max(1024,500)=1024, need=3024; FreeRam=1000 < 3024 → Substitution.
        await Assert.That(d.EffectiveModel).IsEqualTo("claude-sonnet-4-6");
    }
```

- [ ] **Step 2: Run → COMPILE FAIL** (Signatur `EvaluateAsync(string, int, ct)` existiert noch nicht). `dotnet test`.

- [ ] **Step 3: Refactor EvaluateAsync (GPU + CPU Pfad)**

Ersetze die `EvaluateAsync`-Methode in `ResourceGate.cs` (Zeilen 17–66) durch:

```csharp
    public async Task<RoutingDecision> EvaluateAsync(string requestedModel, int inputTokens, CancellationToken ct)
    {
        var opts = options.CurrentValue;
        if (!opts.ResourceGate.Enabled)
            return Proceed(requestedModel, "gate-disabled");

        var (providerName, resolvedModel) = router.Resolve(requestedModel);
        if (!string.Equals(providerName, "ollama", StringComparison.OrdinalIgnoreCase))
            return Proceed(requestedModel, "non-local-provider");

        try
        {
            var profile = await cache.GetAsync(ct);
            var hwClass = classifier.Match(profile, opts.HardwareClasses);
            var validation = hwClass is not null && hwClass.Models.TryGetValue(resolvedModel, out var v) ? v : null;

            if (validation is null)
                return BuildSubstitution(requestedModel, resolvedModel, opts,
                    hwClass is null ? "no matching hardware class" : "no validated footprint");

            var gpuPath = validation.PeakVramMb > 0
                          && !string.Equals(profile.GpuVendor, "none", StringComparison.OrdinalIgnoreCase)
                          && profile.VramMb > 0;

            if (!gpuPath && validation.PeakRamMb <= 0)
                return BuildSubstitution(requestedModel, resolvedModel, opts, "no validated footprint");

            var live = await probe.SampleAsync(resolvedModel, opts.ResourceGate.CpuLoadWindowSeconds, ct);

            if (live.CpuLoadPercent > opts.ResourceGate.CpuMaxLoadPercent)
                return BuildSubstitution(requestedModel, resolvedModel, opts, $"CPU {live.CpuLoadPercent:F0}%");

            if (gpuPath)
            {
                var usableVram = profile.VramMb - opts.ResourceGate.VramDisplayReserveMb;
                if (validation.PeakVramMb > usableVram)
                    return BuildSubstitution(requestedModel, resolvedModel, opts,
                        $"VRAM {validation.PeakVramMb}MB/{usableVram}MB");
            }
            else
            {
                var buffer = opts.ResourceGate.RamBufferMb > 0
                    ? opts.ResourceGate.RamBufferMb
                    : Math.Max(1024, validation.PeakRamMb / 4);
                var need = validation.PeakRamMb + buffer;
                if (live.FreeRamMb < need)
                    return BuildSubstitution(requestedModel, resolvedModel, opts, $"free {live.FreeRamMb}MB/{need}MB");
            }

            // === Task 5 Einhängepunkt: Latenz-Gate (nach bestandener Ressourcen-Admission) ===

            logger.LogInformation(
                "ResourceGate: lokal zugelassen {Model} ({Path}, CPU {Cpu}%, warm={Warm})",
                resolvedModel, gpuPath ? "GPU" : "CPU", live.CpuLoadPercent, live.ModelWarm);
            return Proceed(requestedModel, $"local-admitted {(gpuPath ? "gpu" : "cpu")} warm={live.ModelWarm}");
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            logger.LogWarning(ex,
                "ResourceGate: Ressourcen-Check fehlgeschlagen für {Model} → fail-open (Proceed).", requestedModel);
            return Proceed(requestedModel, "resource-monitor-error");
        }
    }
```

(`BuildSubstitution` und `Proceed` bleiben unverändert.)

- [ ] **Step 4: Fix the endpoint caller (compile)**

In `Program.cs` Zeile ~202 den Aufruf vorläufig auf `gate.EvaluateAsync(requestedModel, 0, ct)` setzen (echte Token-Schätzung kommt in Task 6 — hier nur Compile-Fix). Falls `ResourceGateEndpointTests` `EvaluateAsync` NICHT direkt aufruft (nur über den Endpoint), ist dort keine Änderung nötig.

- [ ] **Step 5: Run all tests → PASS** (MVP-Tests mit `,0,` grün; 3 neue GPU-Tests grün). `dotnet test`; `dotnet format K.Switchboard.slnx`.

- [ ] **Step 6: Commit**

`feat(switchboard): GPU-VRAM-admission-pfad im ResourceGate` → LOWERCASE: `feat(switchboard): gpu-VRAM-admission-pfad im ResourceGate` — bullet body (EvaluateAsync +inputTokens; GPU-pfad VRAM≤Gesamt−reserve parallel zu CPU-RAM-pfad; gemeinsamer CPU-last-check; MVP-tests an signatur angepasst) + `Ref #268`.

---

## Task 5: Latenz-Gate

**Files:**
- Modify: `k.switchboard.net/src/K.Switchboard/Resources/ResourceGate.cs`
- Modify: `k.switchboard.net/tests/K.Switchboard.Tests/Resources/ResourceGateTests.cs`

- [ ] **Step 1: Write failing latency tests**

Im `ResourceGateTests.cs` ergänzen (nutzt einen Helper mit Latenz-Daten + MaxLatencyMs):

```csharp
    private static ResourceGate BuildLatency(LiveResourceSnapshot snap, int latencyP50Ms, int maxLatencyMs, double coldFactor = 2.0)
    {
        var opts = new SwitchboardOptions
        {
            ResourceGate = new ResourceGateOptions
            {
                Enabled = true, CpuMaxLoadPercent = 85,
                MaxLatencyMs = maxLatencyMs, ColdLatencyFactor = coldFactor, LatencyContextReferenceTokens = 4000
            },
            ModelAliases = new() { ["local-coder"] = "qwen2.5-coder:14b" },
            LocalModelTiers = new() { ["qwen2.5-coder:14b"] = "L" },
            TierSubstitutions = new() { ["L"] = "claude-sonnet-4-6" },
            HardwareClasses =
            [
                new()
                {
                    Name = "cpu-32", Match = new() { MinRamMb = 1 },
                    Models = new() { ["qwen2.5-coder:14b"] = new ModelValidation { PeakRamMb = 1000, LatencyP50Ms = latencyP50Ms, ValidatedOn = "rig" } }
                }
            ]
        };
        var optsMon = new FakeOptionsMonitor<SwitchboardOptions>(opts);
        var tmp = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
        Directory.CreateDirectory(tmp);
        var cache = new HardwareProfileCache(
            new FixedDetector(new HardwareProfile { TotalRamMb = 32000, Cores = 8, GpuVendor = "none" }), tmp,
            Microsoft.Extensions.Logging.Abstractions.NullLogger<HardwareProfileCache>.Instance);
        return new ResourceGate(new ModelRouter(optsMon), cache, new HardwareClassifier(), new FakeProbe(snap), optsMon,
            Microsoft.Extensions.Logging.Abstractions.NullLogger<ResourceGate>.Instance);
    }

    [Test]
    public async Task Latency_proceeds_when_warm_under_threshold()
    {
        // warm, P50 40000ms, ctx 0 → factor 0.5 → 20000ms < 100000 → Proceed.
        var gate = BuildLatency(new LiveResourceSnapshot { FreeRamMb = 30000, CpuLoadPercent = 10, ModelWarm = true }, latencyP50Ms: 40000, maxLatencyMs: 100000);
        var d = await gate.EvaluateAsync("local-coder", 0, CancellationToken.None);
        await Assert.That(d.Action).IsEqualTo(RoutingAction.Proceed);
        await Assert.That(d.EffectiveModel).IsEqualTo("local-coder");
    }

    [Test]
    public async Task Latency_substitutes_when_cold_over_threshold()
    {
        // cold, P50 40000ms × cold 2.0 × ctx(4000/4000=1.0) = 80000... unter 100000? nutze ctx 8000 → factor 2.0 → 160000 > 100000.
        var gate = BuildLatency(new LiveResourceSnapshot { FreeRamMb = 30000, CpuLoadPercent = 10, ModelWarm = false }, latencyP50Ms: 40000, maxLatencyMs: 100000);
        var d = await gate.EvaluateAsync("local-coder", 8000, CancellationToken.None);   // ctx-faktor 2.0
        await Assert.That(d.EffectiveModel).IsEqualTo("claude-sonnet-4-6");
    }

    [Test]
    public async Task Latency_gate_inactive_when_maxlatency_zero()
    {
        // MaxLatencyMs=0 → Gate aus, trotz hoher P50 → Proceed.
        var gate = BuildLatency(new LiveResourceSnapshot { FreeRamMb = 30000, CpuLoadPercent = 10, ModelWarm = false }, latencyP50Ms: 999999, maxLatencyMs: 0);
        var d = await gate.EvaluateAsync("local-coder", 8000, CancellationToken.None);
        await Assert.That(d.Action).IsEqualTo(RoutingAction.Proceed);
    }
```

- [ ] **Step 2: Run → FAIL** (`Latency_substitutes...` schlägt fehl, da Latenz-Gate noch nicht existiert → Proceed statt Substitute). `dotnet test`.

- [ ] **Step 3: Add the latency check**

In `ResourceGate.cs` am Einhängepunkt (`// === Task 5 Einhängepunkt ...`) einfügen:

```csharp
            if (LatencyExceeded(validation, live, opts.ResourceGate, inputTokens, out var latReason))
                return BuildSubstitution(requestedModel, resolvedModel, opts, latReason);
```

Und die Helper-Methode (nach `BuildSubstitution`) ergänzen:

```csharp
    private static bool LatencyExceeded(ModelValidation validation, LiveResourceSnapshot live, ResourceGateOptions gate, int inputTokens, out string reason)
    {
        reason = string.Empty;
        if (gate.MaxLatencyMs <= 0 || validation.LatencyP50Ms <= 0)
            return false;   // Gate aus oder keine Latenz-Daten → nicht blockieren

        var contextFactor = Math.Max(0.5, (double)inputTokens / Math.Max(1, gate.LatencyContextReferenceTokens));
        var coldFactor = live.ModelWarm ? 1.0 : gate.ColdLatencyFactor;
        var expectedMs = validation.LatencyP50Ms * coldFactor * contextFactor;
        if (expectedMs > gate.MaxLatencyMs)
        {
            reason = $"latency ~{expectedMs:F0}ms > {gate.MaxLatencyMs}ms (warm={live.ModelWarm}, ctx×{contextFactor:F1})";
            return true;
        }
        return false;
    }
```

- [ ] **Step 4: Run tests → PASS** (3 Latenz-Tests grün, alle übrigen grün). `dotnet test`; `dotnet format K.Switchboard.slnx`.

- [ ] **Step 5: Commit**

`feat(switchboard): latenz-gate (warm/cold × kontext, opt-in)` — bullet body (erwartete latenz = P50 × cold-faktor × kontext-faktor; > MaxLatencyMs → substitution; opt-in MaxLatencyMs=0; greift GPU+CPU-pfad) + `Ref #268`.

---

## Task 6: Endpoint — Input-Token-Schätzung

**Files:**
- Create: `k.switchboard.net/src/K.Switchboard/RequestTokenEstimator.cs`
- Modify: `k.switchboard.net/src/K.Switchboard/Program.cs`
- Test: `k.switchboard.net/tests/K.Switchboard.Tests/RequestTokenEstimatorTests.cs`

- [ ] **Step 1: Write the failing test**

Create `tests/K.Switchboard.Tests/RequestTokenEstimatorTests.cs`:

```csharp
namespace K.Switchboard.Tests;

using System.Text.Json;

public sealed class RequestTokenEstimatorTests
{
    [Test]
    public async Task Estimates_from_string_and_block_content()
    {
        using var doc = JsonDocument.Parse("""
        {"model":"x","messages":[
          {"role":"user","content":"aaaaaaaa"},
          {"role":"assistant","content":[{"type":"text","text":"bbbbbbbb"}]}
        ]}
        """);
        // 8 + 8 = 16 Zeichen / 4 = 4 Tokens.
        var tokens = RequestTokenEstimator.EstimateInputTokens(doc.RootElement);
        await Assert.That(tokens).IsEqualTo(4);
    }

    [Test]
    public async Task Returns_zero_without_messages()
    {
        using var doc = JsonDocument.Parse("""{"model":"x"}""");
        await Assert.That(RequestTokenEstimator.EstimateInputTokens(doc.RootElement)).IsEqualTo(0);
    }
}
```

- [ ] **Step 2: Run → COMPILE FAIL.** `dotnet test`.

- [ ] **Step 3: Implement the estimator**

Create `src/K.Switchboard/RequestTokenEstimator.cs`:

```csharp
namespace K.Switchboard;

using System.Text.Json;

/// <summary>Grobe Input-Token-Schätzung (~4 Zeichen/Token) aus dem Anthropic-Request-Body
/// für die ResourceGate-Latenz-Vorhersage. Best-effort, keine echte Tokenisierung.</summary>
public static class RequestTokenEstimator
{
    /// <summary>Summe der messages[].content-Längen / 4. 0 wenn nicht ermittelbar.</summary>
    public static int EstimateInputTokens(JsonElement root)
    {
        if (!root.TryGetProperty("messages", out var messages) || messages.ValueKind != JsonValueKind.Array)
            return 0;

        var chars = 0;
        foreach (var m in messages.EnumerateArray())
        {
            if (!m.TryGetProperty("content", out var content)) continue;
            if (content.ValueKind == JsonValueKind.String)
            {
                chars += content.GetString()?.Length ?? 0;
            }
            else if (content.ValueKind == JsonValueKind.Array)
            {
                foreach (var block in content.EnumerateArray())
                    if (block.TryGetProperty("text", out var t) && t.ValueKind == JsonValueKind.String)
                        chars += t.GetString()?.Length ?? 0;
            }
        }
        return chars / 4;
    }
}
```

- [ ] **Step 4: Wire into the endpoint**

In `Program.cs`, im `POST /v1/messages`-Handler: An der Stelle, wo der Request-Body für `requestedModel` geparst wird (das bestehende `JsonDocument.Parse`/`JsonDocument.ParseAsync`), die Token-Zahl mit-extrahieren. Da der Body danach mit `ctx.Request.Body.Position = 0` zurückgespult wird, kann der bestehende `doc`/`JsonDocument` genutzt werden. Ergänze nach dem `requestedModel`-Parse eine Variable:

```csharp
        int inputTokens = 0;
        try
        {
            ctx.Request.Body.Position = 0;
            using var tokenDoc = await JsonDocument.ParseAsync(ctx.Request.Body, cancellationToken: ct);
            inputTokens = RequestTokenEstimator.EstimateInputTokens(tokenDoc.RootElement);
            ctx.Request.Body.Position = 0;
        }
        catch (JsonException) { /* best-effort; 0 bleibt */ }
```

(Platziere dies VOR dem `gate.EvaluateAsync`-Aufruf. Falls der bestehende Parse-Block schon ein `JsonDocument` mit dem ganzen Root hält, dort direkt `EstimateInputTokens` aufrufen statt erneut zu parsen — den bestehenden Code lesen und den effizienteren Weg wählen.)

Dann den `EvaluateAsync`-Aufruf (aus Task 4 Step 4 vorläufig `,0,`) auf `inputTokens` setzen:

```csharp
        var decision = await gate.EvaluateAsync(requestedModel, inputTokens, ct);
```

- [ ] **Step 5: Run tests + build → PASS, 0 Warnings.** `dotnet test`; `dotnet build`; `dotnet format K.Switchboard.slnx`.

- [ ] **Step 6: Commit**

`feat(switchboard): input-token-schätzung für latenz-gate im endpoint` — bullet body (RequestTokenEstimator messages-content-länge/4; string + content-blocks; endpoint übergibt inputTokens an EvaluateAsync) + `Ref #268`.

---

## Task 7: Dokumentation

**Files:**
- Modify: `k.switchboard.net/docs/configuration.md`, `troubleshooting.md`, `resource-aware-routing.md`, `eval-measurement.md`

- [ ] **Step 1: configuration.md**

Ergänze in der ResourceGate-Sektion die neuen Felder: `VramDisplayReserveMb` (Default 2048, Headless→0), `MaxLatencyMs` (Default 0=aus; Empfehlung 100000 als Startwert), `ColdLatencyFactor` (2.0), `LatencyContextReferenceTokens` (4000). In der HardwareClasses/ModelValidation-Beschreibung `PeakVramMb` ergänzen (0 = kein GPU-Pfad). GPU-vs-CPU-Admission-Pfad erklären (VRAM-Admission gegen statisches VRAM − Reserve; rocm-smi für AMD). **macOS-Eintrag in der hw-profile.json-Tabelle als „nicht unterstützt" markieren** (statt Pfad-Angabe: „macOS — nicht unterstützt").

- [ ] **Step 2: troubleshooting.md**

Neue Einträge: „GPU-Modell wird trotz GPU substituiert" (PeakVramMb > VRAM−Reserve; Reserve via VramDisplayReserveMb anpassen / headless 0), „Request wegen Latenz substituiert" (MaxLatencyMs greift; Header/Log lesen; Schwelle anpassen oder Gate via MaxLatencyMs=0 deaktivieren), „AMD-GPU nicht erkannt" (rocm-smi nicht installiert/PATH → CPU-Pfad).

- [ ] **Step 3: resource-aware-routing.md**

Im Datenfluss-Diagramm den GPU-Pfad (VRAM-Admission) parallel zum CPU-Pfad (RAM-Admission) + den Latenz-Check (nach Admission, vor Proceed) ergänzen. macOS als nicht unterstützt erwähnen.

- [ ] **Step 4: eval-measurement.md**

Sektion ergänzen: Cold-Load-Messlauf (für ColdLatencyFactor-Kalibrierung) + PeakVramMb-Erhebung (`/api/ps` `size_vram` beim GPU-Cold-Load). Tabelle um eine VRAM-Spalte erweitern; weiterhin „ausstehend" wo nicht gemessen.

- [ ] **Step 5: Commit**

`docs(switchboard): GPU-pfad + latenz-gate dokumentiert` → LOWERCASE: `docs(switchboard): gpu-pfad + latenz-gate dokumentiert` — bullet body (configuration: vram-reserve/max-latency/cold-faktor/PeakVramMb/rocm-smi + macOS nicht unterstützt; troubleshooting: VRAM/latenz/AMD-gründe; resource-aware-routing: GPU-pfad im datenfluss; eval-measurement: cold-load + VRAM) + `Ref #268`.

---

## Self-Review

**Spec-Coverage (§-für-§):**
- §2 GPU-Pfad/VRAM-Admission → Task 1 (PeakVramMb, VramDisplayReserveMb) + Task 2 (rocm-smi) + Task 4 (VRAM-Admission-Pfad) ✓
- §3 Latenz-Gate → Task 1 (Felder) + Task 5 (Check) + Task 6 (inputTokens) ✓
- §4 CPU-Sampler Windows → Task 3 ✓
- §5 Tests → in jeder Task ✓ · §6 CreateDefault-Defaults → Task 1 ✓ · §7 Docs → Task 7 ✓
- §8 Akzeptanzkriterien: alle abgedeckt. macOS durchgehend ausgeschlossen.

**Type-Konsistenz:** `EvaluateAsync(string, int, CancellationToken)` einheitlich (Task 4 definiert, Task 5/6 nutzen). `ModelValidation.PeakVramMb`, `ResourceGateOptions.{VramDisplayReserveMb,MaxLatencyMs,ColdLatencyFactor,LatencyContextReferenceTokens}`, `RequestTokenEstimator.EstimateInputTokens(JsonElement)`, `CpuLoadSampler` (partial), `LatencyExceeded(ModelValidation, LiveResourceSnapshot, ResourceGateOptions, int, out string)` — konsistent.

**Abhängigkeiten:** Task 4 ändert die Signatur (alle Aufrufer/Tests anpassen) und legt den Latenz-Einhängepunkt; Task 5 dockt dort an; Task 6 liefert echte inputTokens. Reihenfolge zwingend 1→2→3→4→5→6→7.

**Offen/bewusst:** GPU-Pfad prüft kein freies RAM separat (Modell im VRAM; CPU-Last-Check bleibt). VRAM ist statisch (Gesamt, kein Live-Frei) — Display-Reserve deckt das ab. Token-Schätzung ist grob (Zeichen/4), genügt für die grobe Latenz-Heuristik.

---

## Execution Handoff

**Plan gespeichert unter `docs/superpowers/plans/2026-06-07-resource-aware-routing-plus1.md`.** Umsetzung via `superpowers:subagent-driven-development` (CLAUDE.md-Vorgabe) — frischer Subagent pro Task, Spec+Quality-Review zwischen den Tasks. Branch `feature/268-resource-gate-plus1`, kein Push ohne Auftrag, `dotnet format` + Train-Check vor Push.

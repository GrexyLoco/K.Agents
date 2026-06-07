# ResourceGate (Ressourcen-bewusstes Routing) — MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein Pre-flight-`ResourceGate` in K.Switchboard, das pro Request entscheidet, ob das primär angefragte lokale Ollama-Modell *jetzt* ausführbar ist, und sonst transparent (geloggt + Header) auf ein Claude-Modell substituiert oder klar mit HTTP 5xx fehlschlägt — ohne die Maschine durch Swapping lahmzulegen.

**Architecture:** Neuer Service `ResourceGate` im `POST /v1/messages`-Endpoint **vor** `FallbackService.ForwardWithFallbackAsync`. Er nutzt ein gecachtes statisches HW-Profil (per-install, nicht committed), eine billige Live-Probe (freier RAM, CPU-Last, Ollama `/api/ps`-Warmth) und zwei committed Config-Mappings (HW-Klasse→Modell, lokales-Modell→Tier→Claude-Substitut). Der bestehende `FallbackService` bleibt unverändert für reaktive HTTP-Fehler. Ein Blast-Radius-Cap (`num_thread = Kerne−2`, `SemaphoreSlim(1)`) im `OllamaProvider` schützt die Maschine bei erlaubtem lokalem Lauf.

**Tech Stack:** C# / .NET 10, ASP.NET Core Minimal API, `IOptionsMonitor`/`IOptionsSnapshot` (config.json Hot-Reload), source-generated JSON (`SwitchboardJsonContext`, AOT/trim-safe), Serilog, TUnit (Tests), PowerShell (Evals).

**Spec:** [docs/superpowers/specs/2026-06-07-resource-aware-routing-design.md](../specs/2026-06-07-resource-aware-routing-design.md)

**Scope dieses Plans:** MVP (siehe Spec §10). Ausbau +1 (GPU-Pfad/Latenz) und +2 (Prozess-Priorität/Mapping-Selbstpflege) folgen als separate Pläne im selben v1.21.0-Train.

---

## Konventionen (für jeden ausführenden Subagenten)

- **Arbeitsverzeichnis-Anker:** Repo-Root `c:\Users\gkump\source\repos\1d70f\K.Agents`. Switchboard-Projekt: `k.switchboard.net/src/K.Switchboard/`. Tests: `k.switchboard.net/tests/K.Switchboard.Tests/`.
- **Build/Test:** Aus `k.switchboard.net/`:
  - Build: `dotnet build`
  - Einzeltest: `dotnet test --filter "FullyQualifiedName~<TestName>"`
  - Alle Tests: `dotnet test`
- **Sprache:** XML-Doc + Kommentare auf Deutsch (bestehende Konvention), Identifier englisch.
- **Stil:** `sealed record`/`sealed class`, primary constructors, file-scoped namespace `K.Switchboard.Resources` für neue Typen, nullable enabled. Folge bestehendem Code (z.B. `SwitchboardOptions.cs`, `FallbackService.cs`).
- **Commit-Format (CI „Conventional Commits"):** `type(scope): description` — description **klein** beginnen; Body als Bulletpoints; nur `Ref #268` (kein `Closes`, das kommt erst beim Stable-Promo). Scope = `switchboard`.
- **ReleaseFlow:** NICHT pushen ohne expliziten Auftrag. Branch ist `feature/268-resource-aware-routing` (bereits angelegt von `dev/v1.21.0`). Commits lokal sammeln.
- **AOT-Regel:** Jeder Typ, der **standalone** (de)serialisiert wird, MUSS in `SwitchboardJsonContext` mit `[JsonSerializable(typeof(...))]` registriert werden. Typen, die nur als Property von `SwitchboardOptions` vorkommen, sind über dessen Registrierung abgedeckt.

## File Structure

**Neue Dateien (`src/K.Switchboard/Resources/`):**

| Datei | Verantwortung |
|---|---|
| `HardwareProfile.cs` | `record HardwareProfile` — erkannte Maschinen-Eigenschaften (a) + `DetectedOn`. Cache-serialisiert. |
| `IProcessRunner.cs` / `ProcessRunner.cs` | Dünne Subprocess-Abstraktion (testbar): führt CLI aus, liefert stdout/Exit. |
| `IHardwareProfileDetector.cs` / `HardwareProfileDetector.cs` | RAM/CPU via .NET-APIs; GPU/VRAM via `IProcessRunner` (nvidia-smi/wmic/sysctl). |
| `HardwareProfileCache.cs` | Lädt/speichert Profil als `hw-profile.json` (ApplicationData, uncommitted); Refresh bei leer/Monatswechsel. |
| `HardwareClassifier.cs` | Ordnet `HardwareProfile` einer `HardwareClassConfig` zu (RAM/Vendor/VRAM-Match). |
| `LiveResourceSnapshot.cs` | `record` — freier RAM, CPU-Last %, Modell-Warmth (aus `/api/ps`). |
| `ILiveResourceProbe.cs` / `LiveResourceProbe.cs` | Billige Live-Reads pro Request. |
| `RoutingDecision.cs` | `record` — Entscheidung (RunLocal/Substitute/Fail) + Grund + effektives Modell + Header-Text. |
| `ResourceGate.cs` | Orchestriert: resolve → profile → classify → admission → decision. |
| `LocalInferenceGate.cs` | `SemaphoreSlim(1)`-Wrapper (Serialisierung lokaler Inferenz), Singleton. |

**Modifizierte Dateien:**

| Datei | Änderung |
|---|---|
| `SwitchboardOptions.cs` | Neue Properties + Records (`HardwareClassConfig`, `HardwareClassMatch`, `ModelValidation`, `ResourceGateOptions`). |
| `SwitchboardJsonContext.cs` | `[JsonSerializable(typeof(HardwareProfile))]`. |
| `Providers/OllamaProvider.cs` | `num_thread = Kerne−2` in `options`; lokale Inferenz über `LocalInferenceGate` serialisieren. |
| `Program.cs` | DI-Registrierung der neuen Services; `ResourceGate` im `/v1/messages`-Endpoint vor `ForwardWithFallbackAsync`; Substitutions-Header. |
| `.gitignore` (Repo-Root oder `k.switchboard.net/`) | `hw-profile.json`. |

**Neue Test-Dateien (`tests/K.Switchboard.Tests/Resources/`):** je Komponente (siehe Tasks).

**Eval/Docs:** `plugins/kagents/agents/*/evals/run-evals.ps1` (erweitern), `k.switchboard.net/docs/eval-measurement.md` (neu), `resource-aware-routing.md` (neu), `configuration.md` + `troubleshooting.md` (erweitern).

---

## Task 1: Config-Records (committed Mappings + Gate-Optionen)

**Files:**
- Modify: `k.switchboard.net/src/K.Switchboard/SwitchboardOptions.cs`
- Test: `k.switchboard.net/tests/K.Switchboard.Tests/Resources/SwitchboardOptionsResourceTests.cs`

- [ ] **Step 1: Write the failing test**

Create `k.switchboard.net/tests/K.Switchboard.Tests/Resources/SwitchboardOptionsResourceTests.cs`:

```csharp
namespace K.Switchboard.Tests.Resources;

using System.Text.Json;

public sealed class SwitchboardOptionsResourceTests
{
    [Test]
    public async Task Deserializes_resource_config_sections()
    {
        const string json = """
        {
          "LocalModelTiers": { "llama3.2:3b": "S", "qwen2.5-coder:14b": "L" },
          "TierSubstitutions": { "S": "claude-haiku-4-5", "L": "claude-sonnet-4-6" },
          "ResourceGate": { "enabled": true, "ramBufferMb": 0, "cpuLoadWindowSeconds": 4, "cpuMaxLoadPercent": 85 },
          "HardwareClasses": [
            { "name": "gpu-14b",
              "match": { "minRamMb": 24576, "gpuVendor": "NVIDIA", "minVramMb": 10240, "maxVramMb": 16383 },
              "models": { "qwen2.5-coder:14b": { "peakRamMb": 11000, "validatedOn": "rig-x", "latencyP50Ms": 4200, "score": "B" } } }
          ]
        }
        """;

        var opts = JsonSerializer.Deserialize<SwitchboardOptions>(json,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true })!;

        await Assert.That(opts.LocalModelTiers["qwen2.5-coder:14b"]).IsEqualTo("L");
        await Assert.That(opts.TierSubstitutions["S"]).IsEqualTo("claude-haiku-4-5");
        await Assert.That(opts.ResourceGate.CpuMaxLoadPercent).IsEqualTo(85);
        await Assert.That(opts.HardwareClasses[0].Name).IsEqualTo("gpu-14b");
        await Assert.That(opts.HardwareClasses[0].Match.MinVramMb).IsEqualTo(10240);
        await Assert.That(opts.HardwareClasses[0].Models["qwen2.5-coder:14b"].PeakRamMb).IsEqualTo(11000);
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dotnet test --filter "FullyQualifiedName~SwitchboardOptionsResourceTests"` (aus `k.switchboard.net/`)
Expected: COMPILE FAIL — `LocalModelTiers`, `TierSubstitutions`, `ResourceGate`, `HardwareClasses` existieren nicht.

- [ ] **Step 3: Add config properties + records**

In `SwitchboardOptions.cs`, innerhalb des `SwitchboardOptions`-records nach `SavingsBaseline` (Zeile 45) ergänzen:

```csharp
    /// <summary>Lokales Ollama-Modell → Aufgaben-Tier (S/M/L). Basis für die Substitution.</summary>
    public Dictionary<string, string> LocalModelTiers { get; init; } = [];

    /// <summary>Tier (S/M/L) → Claude-Substitut-Modell, falls das lokale Modell nicht ausführbar ist.</summary>
    public Dictionary<string, string> TierSubstitutions { get; init; } = [];

    /// <summary>Kuratierte HW-Klassen (committed): welche lokalen Modelle pro Klasse tauglich sind.</summary>
    public List<HardwareClassConfig> HardwareClasses { get; init; } = [];

    /// <summary>Einstellungen des ResourceGate (Pre-flight-Ressourcen-Check).</summary>
    public ResourceGateOptions ResourceGate { get; init; } = new();
```

Am Dateiende (nach `ModelPricing`) neue Records:

```csharp
/// <summary>Eine kuratierte HW-Klasse: Match-Kriterien + tauglich-validierte Modelle.</summary>
public sealed record HardwareClassConfig
{
    /// <summary>Eindeutiger Klassenname (z.B. "gpu-14b", "cpu-low").</summary>
    public string Name { get; init; } = string.Empty;

    /// <summary>Match-Kriterien gegen das erkannte HW-Profil.</summary>
    public HardwareClassMatch Match { get; init; } = new();

    /// <summary>Tauglich-validierte lokale Modelle dieser Klasse (Key = Ollama-Modellname).
    /// Leer = keine lokalen Modelle tauglich → immer substituieren.</summary>
    public Dictionary<string, ModelValidation> Models { get; init; } = [];
}

/// <summary>Match-Kriterien einer HW-Klasse. Null-Felder werden ignoriert (kein Constraint).</summary>
public sealed record HardwareClassMatch
{
    /// <summary>Minimaler Gesamt-RAM in MB (inklusive).</summary>
    public int? MinRamMb { get; init; }

    /// <summary>Maximaler Gesamt-RAM in MB (inklusive).</summary>
    public int? MaxRamMb { get; init; }

    /// <summary>Minimale CPU-Kernzahl (inklusive).</summary>
    public int? MinCores { get; init; }

    /// <summary>GPU-Vendor: "NVIDIA", "AMD" oder "none". Null = egal.</summary>
    public string? GpuVendor { get; init; }

    /// <summary>Minimaler VRAM in MB (inklusive).</summary>
    public int? MinVramMb { get; init; }

    /// <summary>Maximaler VRAM in MB (inklusive).</summary>
    public int? MaxVramMb { get; init; }
}

/// <summary>Empirische Validierungs-Daten eines lokalen Modells auf einer HW-Klasse.</summary>
public sealed record ModelValidation
{
    /// <summary>Beobachteter Peak-RAM (MB) beim realistischen Max-Kontext. 0 = nicht gemessen (Default nutzen).</summary>
    public int PeakRamMb { get; init; }

    /// <summary>Setup-Beschreibung, auf dem gemessen wurde (Reproduzierbarkeit, siehe eval-measurement.md).</summary>
    public string ValidatedOn { get; init; } = string.Empty;

    /// <summary>Median-Latenz (ms) im Eval. 0 = nicht gemessen.</summary>
    public int LatencyP50Ms { get; init; }

    /// <summary>Qualitäts-Score (A/B/C/F) aus dem Eval. Leer = nicht bewertet.</summary>
    public string Score { get; init; } = string.Empty;
}

/// <summary>Einstellungen des ResourceGate.</summary>
public sealed record ResourceGateOptions
{
    /// <summary>Gate aktiv? Default false → backward-kompatibel (fehlende Config = Gate aus).</summary>
    public bool Enabled { get; init; }

    /// <summary>Zusätzlicher RAM-Sicherheitspuffer (MB) über PeakRamMb. 0 = im Code hergeleiteter Default.</summary>
    public int RamBufferMb { get; init; }

    /// <summary>Fenster (Sekunden) für den rollenden CPU-Last-Mittelwert.</summary>
    public int CpuLoadWindowSeconds { get; init; } = 4;

    /// <summary>CPU-Last-Schwelle (%), oberhalb derer lokale Inferenz blockiert wird.</summary>
    public int CpuMaxLoadPercent { get; init; } = 85;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `dotnet test --filter "FullyQualifiedName~SwitchboardOptionsResourceTests"`
Expected: PASS.

- [ ] **Step 5: Commit**

Commit-Message (Format siehe Konventionen): `feat(switchboard): config-records für ResourceGate` mit Bulletpoint-Body (LocalModelTiers+TierSubstitutions, HardwareClasses, ResourceGateOptions) und `Ref #268`. Stage: die geänderte `SwitchboardOptions.cs` + neue Testdatei.

---

## Task 2: HardwareProfile + Subprocess-Detektor

**Files:**
- Create: `k.switchboard.net/src/K.Switchboard/Resources/HardwareProfile.cs`
- Create: `k.switchboard.net/src/K.Switchboard/Resources/IProcessRunner.cs`
- Create: `k.switchboard.net/src/K.Switchboard/Resources/ProcessRunner.cs`
- Create: `k.switchboard.net/src/K.Switchboard/Resources/IHardwareProfileDetector.cs`
- Create: `k.switchboard.net/src/K.Switchboard/Resources/HardwareProfileDetector.cs`
- Modify: `k.switchboard.net/src/K.Switchboard/SwitchboardJsonContext.cs`
- Test: `k.switchboard.net/tests/K.Switchboard.Tests/Resources/HardwareProfileDetectorTests.cs`

- [ ] **Step 1: Define HardwareProfile record + register for JSON**

Create `Resources/HardwareProfile.cs`:

```csharp
namespace K.Switchboard.Resources;

/// <summary>
/// Erkanntes Maschinen-Profil (a) — maschinenspezifisch, im Per-Install-Cache gehalten,
/// NICHT committed. Siehe Spec §3.2.
/// </summary>
public sealed record HardwareProfile
{
    /// <summary>Gesamter System-RAM in MB.</summary>
    public int TotalRamMb { get; init; }

    /// <summary>Logische CPU-Kerne.</summary>
    public int Cores { get; init; }

    /// <summary>GPU-Vendor: "NVIDIA", "AMD" oder "none".</summary>
    public string GpuVendor { get; init; } = "none";

    /// <summary>GPU-Modellname (oder leer).</summary>
    public string GpuModel { get; init; } = string.Empty;

    /// <summary>VRAM in MB (0 = keine/unbekannte GPU).</summary>
    public int VramMb { get; init; }

    /// <summary>UTC-Zeitpunkt der Erkennung (für monatlichen Refresh).</summary>
    public DateTimeOffset DetectedOn { get; init; }
}
```

In `SwitchboardJsonContext.cs` nach Zeile 15 (`[JsonSerializable(typeof(ProblemDetails))]`) ergänzen:

```csharp
[JsonSerializable(typeof(K.Switchboard.Resources.HardwareProfile))]
```

- [ ] **Step 2: Write the failing detector test**

Create `Resources/HardwareProfileDetectorTests.cs`:

```csharp
namespace K.Switchboard.Tests.Resources;

using K.Switchboard.Resources;

public sealed class HardwareProfileDetectorTests
{
    private sealed class FakeProcessRunner(Dictionary<string, (int Exit, string Out)> map) : IProcessRunner
    {
        public Task<(int ExitCode, string StdOut)> RunAsync(string file, string args, CancellationToken ct)
            => Task.FromResult(map.TryGetValue(file, out var r) ? (r.Exit, r.Out) : (1, string.Empty));
    }

    [Test]
    public async Task Detects_nvidia_gpu_from_smi()
    {
        var runner = new FakeProcessRunner(new()
        {
            ["nvidia-smi"] = (0, "NVIDIA GeForce RTX 5070 Ti, 16384\n")
        });
        var detector = new HardwareProfileDetector(runner,
            Microsoft.Extensions.Logging.Abstractions.NullLogger<HardwareProfileDetector>.Instance);

        var profile = await detector.DetectAsync(CancellationToken.None);

        await Assert.That(profile.GpuVendor).IsEqualTo("NVIDIA");
        await Assert.That(profile.VramMb).IsEqualTo(16384);
        await Assert.That(profile.GpuModel).Contains("5070");
        await Assert.That(profile.Cores).IsGreaterThan(0);
        await Assert.That(profile.TotalRamMb).IsGreaterThan(0);
    }

    [Test]
    public async Task Falls_back_to_none_when_no_gpu_tool()
    {
        var runner = new FakeProcessRunner(new());   // alle CLIs fehlen → Exit 1
        var detector = new HardwareProfileDetector(runner,
            Microsoft.Extensions.Logging.Abstractions.NullLogger<HardwareProfileDetector>.Instance);

        var profile = await detector.DetectAsync(CancellationToken.None);

        await Assert.That(profile.GpuVendor).IsEqualTo("none");
        await Assert.That(profile.VramMb).IsEqualTo(0);
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `dotnet test --filter "FullyQualifiedName~HardwareProfileDetectorTests"`
Expected: COMPILE FAIL — `IProcessRunner`, `HardwareProfileDetector` fehlen.

- [ ] **Step 4: Implement IProcessRunner + ProcessRunner**

Create `Resources/IProcessRunner.cs`:

```csharp
namespace K.Switchboard.Resources;

/// <summary>Dünne, testbare Abstraktion für CLI-Subprozesse (GPU-Detektion).</summary>
public interface IProcessRunner
{
    /// <summary>Führt <paramref name="file"/> mit <paramref name="args"/> aus.
    /// Liefert Exit-Code + stdout. Wirft NICHT bei Nicht-Null-Exit; Fehler = (Exit≠0).</summary>
    Task<(int ExitCode, string StdOut)> RunAsync(string file, string args, CancellationToken ct);
}
```

Create `Resources/ProcessRunner.cs`:

```csharp
namespace K.Switchboard.Resources;

using System.Diagnostics;

/// <summary>Produktive <see cref="IProcessRunner"/>-Implementierung. Schluckt fehlende Binaries.</summary>
public sealed class ProcessRunner : IProcessRunner
{
    public async Task<(int ExitCode, string StdOut)> RunAsync(string file, string args, CancellationToken ct)
    {
        try
        {
            using var proc = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = file,
                    Arguments = args,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true
                }
            };
            if (!proc.Start())
                return (1, string.Empty);

            var stdout = await proc.StandardOutput.ReadToEndAsync(ct);
            await proc.WaitForExitAsync(ct);
            return (proc.ExitCode, stdout);
        }
        catch (Exception)   // Binary nicht im PATH / Plattform ohne Tool → kein harter Fehler
        {
            return (1, string.Empty);
        }
    }
}
```

- [ ] **Step 5: Implement detector**

Create `Resources/IHardwareProfileDetector.cs`:

```csharp
namespace K.Switchboard.Resources;

/// <summary>Erkennt das statische HW-Profil (a) der aktuellen Maschine.</summary>
public interface IHardwareProfileDetector
{
    /// <summary>Erkennt RAM/CPU (.NET-APIs) + GPU/VRAM (Subprozess). DetectedOn = jetzt (UTC).</summary>
    Task<HardwareProfile> DetectAsync(CancellationToken ct);
}
```

Create `Resources/HardwareProfileDetector.cs`:

```csharp
namespace K.Switchboard.Resources;

using System.Globalization;
using System.Runtime.InteropServices;

/// <summary>
/// RAM/CPU via .NET-APIs (trim-safe, keine P/Invoke); GPU/VRAM via CLI-Subprozess je OS.
/// Fehlt das GPU-Tool, wird GpuVendor="none" gesetzt (CPU-Pfad). Siehe Spec §3.1.
/// </summary>
public sealed class HardwareProfileDetector(
    IProcessRunner runner,
    ILogger<HardwareProfileDetector> logger) : IHardwareProfileDetector
{
    public async Task<HardwareProfile> DetectAsync(CancellationToken ct)
    {
        var totalRamMb = (int)(GC.GetGCMemoryInfo().TotalAvailableMemoryBytes / (1024 * 1024));
        var cores = Environment.ProcessorCount;
        var (vendor, model, vram) = await DetectGpuAsync(ct);

        var profile = new HardwareProfile
        {
            TotalRamMb = totalRamMb,
            Cores = cores,
            GpuVendor = vendor,
            GpuModel = model,
            VramMb = vram,
            DetectedOn = DateTimeOffset.UtcNow
        };
        logger.LogInformation(
            "HW-Profil erkannt: RAM={RamMb}MB Cores={Cores} GPU={Vendor}/{Model} VRAM={VramMb}MB",
            totalRamMb, cores, vendor, model, vram);
        return profile;
    }

    private async Task<(string Vendor, string Model, int VramMb)> DetectGpuAsync(CancellationToken ct)
    {
        // 1) NVIDIA via nvidia-smi (cross-platform, falls Treiber installiert)
        var (exit, output) = await runner.RunAsync(
            "nvidia-smi", "--query-gpu=name,memory.total --format=csv,noheader,nounits", ct);
        if (exit == 0 && !string.IsNullOrWhiteSpace(output))
        {
            var line = output.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                             .FirstOrDefault() ?? string.Empty;
            var parts = line.Split(',', StringSplitOptions.TrimEntries);
            if (parts.Length >= 2 && int.TryParse(parts[1], NumberStyles.Integer, CultureInfo.InvariantCulture, out var mb))
                return ("NVIDIA", parts[0], mb);
        }

        // 2) Windows-Fallback: wmic VideoController (AdapterRAM in Bytes)
        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            var (wexit, wout) = await runner.RunAsync(
                "wmic", "path win32_VideoController get name,AdapterRAM /format:csv", ct);
            if (wexit == 0 && !string.IsNullOrWhiteSpace(wout))
            {
                var (vendor, model, vram) = ParseWmic(wout);
                if (!string.IsNullOrEmpty(model))
                    return (vendor, model, vram);
            }
        }

        // 3) macOS-Fallback: system_profiler (VRAM nicht zuverlässig parsebar → 0, CPU-Pfad)
        if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
        {
            var (mexit, mout) = await runner.RunAsync("system_profiler", "SPDisplaysDataType", ct);
            if (mexit == 0 && mout.Contains("Chipset Model", StringComparison.OrdinalIgnoreCase))
                return ("AMD", "apple-or-amd-gpu", 0);
        }

        logger.LogInformation("Keine GPU erkannt (Tool fehlt/Exit≠0) → CPU-Pfad.");
        return ("none", string.Empty, 0);
    }

    private static (string Vendor, string Model, int VramMb) ParseWmic(string csv)
    {
        // CSV-Zeilen: Node,AdapterRAM,Name — Header überspringen, erste Datenzeile nutzen.
        foreach (var raw in csv.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            if (raw.StartsWith("Node", StringComparison.OrdinalIgnoreCase)) continue;
            var cols = raw.Split(',', StringSplitOptions.TrimEntries);
            if (cols.Length < 3) continue;
            var name = cols[2];
            _ = long.TryParse(cols[1], out var bytes);
            var vendor = name.Contains("NVIDIA", StringComparison.OrdinalIgnoreCase) ? "NVIDIA"
                       : name.Contains("AMD", StringComparison.OrdinalIgnoreCase)
                         || name.Contains("Radeon", StringComparison.OrdinalIgnoreCase) ? "AMD" : "none";
            return (vendor, name, (int)(bytes / (1024 * 1024)));
        }
        return ("none", string.Empty, 0);
    }
}
```

> **Hinweis:** `wmic` `AdapterRAM` ist als 32-bit-Wert auf >4 GB-GPUs unzuverlässig (Überlauf). Im MVP akzeptabel (Windows-NVIDIA läuft über nvidia-smi-Pfad 1); der wmic-Pfad ist nur Fallback für GPUs ohne nvidia-smi. Ausbau +1 verfeinert AMD/VRAM. `wmic` ist auf neuen Windows deprecated — fehlt es, greift Pfad 3/none, kein Fehler.

- [ ] **Step 6: Run tests to verify they pass**

Run: `dotnet test --filter "FullyQualifiedName~HardwareProfileDetectorTests"`
Expected: PASS (beide Tests).

- [ ] **Step 7: Commit**

Commit `feat(switchboard): HW-profil-detektor (RAM/CPU/GPU)` mit Bulletpoint-Body (HardwareProfile-record + JSON-context-registrierung; IProcessRunner+ProcessRunner; Detektor mit nvidia-smi/wmic/system_profiler; Tool fehlt → none) und `Ref #268`. Stage: neuer `Resources/`-Ordner, `SwitchboardJsonContext.cs`, Testdatei.

---

## Task 3: HardwareProfileCache (Per-Install, Refresh-Logik)

**Files:**
- Create: `k.switchboard.net/src/K.Switchboard/Resources/HardwareProfileCache.cs`
- Test: `k.switchboard.net/tests/K.Switchboard.Tests/Resources/HardwareProfileCacheTests.cs`

- [ ] **Step 1: Write the failing test**

Create `Resources/HardwareProfileCacheTests.cs`. Cache nimmt ein Verzeichnis (injizierbar, analog `CostingService(optsMon, logger, tmpDir)`) und einen Detektor. Testet: (1) leerer Cache → Detektor läuft, Datei geschrieben; (2) frischer Cache (gleicher Monat) → Detektor läuft NICHT; (3) Cache aus Vormonat → Detektor läuft erneut.

```csharp
namespace K.Switchboard.Tests.Resources;

using K.Switchboard.Resources;

public sealed class HardwareProfileCacheTests
{
    private sealed class CountingDetector(HardwareProfile profile) : IHardwareProfileDetector
    {
        public int Calls { get; private set; }
        public Task<HardwareProfile> DetectAsync(CancellationToken ct)
        {
            Calls++;
            return Task.FromResult(profile with { DetectedOn = DateTimeOffset.UtcNow });
        }
    }

    private static string FreshTempDir()
    {
        var dir = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
        Directory.CreateDirectory(dir);
        return dir;
    }

    [Test]
    public async Task Detects_and_persists_when_cache_empty()
    {
        var dir = FreshTempDir();
        var detector = new CountingDetector(new HardwareProfile { TotalRamMb = 32000, Cores = 8 });
        var cache = new HardwareProfileCache(detector, dir,
            Microsoft.Extensions.Logging.Abstractions.NullLogger<HardwareProfileCache>.Instance);

        var p = await cache.GetAsync(CancellationToken.None);

        await Assert.That(detector.Calls).IsEqualTo(1);
        await Assert.That(p.TotalRamMb).IsEqualTo(32000);
        await Assert.That(File.Exists(Path.Combine(dir, "hw-profile.json"))).IsTrue();
    }

    [Test]
    public async Task Reuses_cache_within_same_month()
    {
        var dir = FreshTempDir();
        var detector = new CountingDetector(new HardwareProfile { TotalRamMb = 32000, Cores = 8 });
        var cache = new HardwareProfileCache(detector, dir,
            Microsoft.Extensions.Logging.Abstractions.NullLogger<HardwareProfileCache>.Instance);

        await cache.GetAsync(CancellationToken.None);   // schreibt
        await cache.GetAsync(CancellationToken.None);   // sollte lesen, nicht detektieren

        await Assert.That(detector.Calls).IsEqualTo(1);
    }

    [Test]
    public async Task Refreshes_when_cached_profile_from_previous_month()
    {
        var dir = FreshTempDir();
        // Cache-Datei mit DetectedOn = vor 40 Tagen vorab schreiben
        var stale = new HardwareProfile { TotalRamMb = 16000, Cores = 4, DetectedOn = DateTimeOffset.UtcNow.AddDays(-40) };
        await File.WriteAllTextAsync(Path.Combine(dir, "hw-profile.json"),
            System.Text.Json.JsonSerializer.Serialize(stale));
        var detector = new CountingDetector(new HardwareProfile { TotalRamMb = 32000, Cores = 8 });
        var cache = new HardwareProfileCache(detector, dir,
            Microsoft.Extensions.Logging.Abstractions.NullLogger<HardwareProfileCache>.Instance);

        var p = await cache.GetAsync(CancellationToken.None);

        await Assert.That(detector.Calls).IsEqualTo(1);
        await Assert.That(p.TotalRamMb).IsEqualTo(32000);   // frisch erkannt, nicht der stale-Wert
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dotnet test --filter "FullyQualifiedName~HardwareProfileCacheTests"`
Expected: COMPILE FAIL — `HardwareProfileCache` fehlt.

- [ ] **Step 3: Implement the cache**

Create `Resources/HardwareProfileCache.cs`:

```csharp
namespace K.Switchboard.Resources;

using System.Text.Json;

/// <summary>
/// Hält das erkannte HW-Profil (a) als <c>hw-profile.json</c> im Per-Install-Verzeichnis
/// (ApplicationData, NICHT committed). Refresh bei leer/unlesbar ODER wenn der zuletzt erkannte
/// Monat (UTC) nicht der aktuelle ist (1×/Monat). Siehe Spec §3.2.
/// </summary>
public sealed class HardwareProfileCache
{
    private readonly IHardwareProfileDetector _detector;
    private readonly string _filePath;
    private readonly ILogger<HardwareProfileCache> _logger;
    private readonly SemaphoreSlim _lock = new(1, 1);
    private HardwareProfile? _memo;

    /// <summary>Produktiver ctor: nutzt %APPDATA%/K.Switchboard (cross-platform ApplicationData).</summary>
    public HardwareProfileCache(IHardwareProfileDetector detector, ILogger<HardwareProfileCache> logger)
        : this(detector,
               Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "K.Switchboard"),
               logger)
    { }

    /// <summary>Test-ctor mit explizitem Verzeichnis (analog CostingService).</summary>
    public HardwareProfileCache(IHardwareProfileDetector detector, string directory, ILogger<HardwareProfileCache> logger)
    {
        _detector = detector;
        Directory.CreateDirectory(directory);
        _filePath = Path.Combine(directory, "hw-profile.json");
        _logger = logger;
    }

    /// <summary>Liefert das (ggf. neu erkannte) Profil.</summary>
    public async Task<HardwareProfile> GetAsync(CancellationToken ct)
    {
        if (_memo is { } m && IsCurrentMonth(m.DetectedOn))
            return m;

        await _lock.WaitAsync(ct);
        try
        {
            var loaded = TryLoad();
            if (loaded is { } p && IsCurrentMonth(p.DetectedOn))
            {
                _memo = p;
                return p;
            }

            _logger.LogInformation("HW-Profil-Cache leer/veraltet → Neu-Detektion.");
            var fresh = await _detector.DetectAsync(ct);
            await SaveAsync(fresh, ct);
            _memo = fresh;
            return fresh;
        }
        finally
        {
            _lock.Release();
        }
    }

    private static bool IsCurrentMonth(DateTimeOffset detectedOn)
    {
        var now = DateTimeOffset.UtcNow;
        return detectedOn.Year == now.Year && detectedOn.Month == now.Month;
    }

    private HardwareProfile? TryLoad()
    {
        try
        {
            if (!File.Exists(_filePath)) return null;
            var json = File.ReadAllText(_filePath);
            return JsonSerializer.Deserialize<HardwareProfile>(json);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "HW-Profil-Cache unlesbar — wird neu erkannt.");
            return null;
        }
    }

    private async Task SaveAsync(HardwareProfile profile, CancellationToken ct)
    {
        try
        {
            var json = JsonSerializer.Serialize(profile);
            await File.WriteAllTextAsync(_filePath, json, ct);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "HW-Profil-Cache konnte nicht geschrieben werden ({Path}).", _filePath);
        }
    }
}
```

> **Hinweis:** `JsonSerializer.Serialize/Deserialize<HardwareProfile>` ohne expliziten Context nutzt im Test-Projekt (kein Trimming) Reflection. In der getrimmten App läuft Persistenz über den in Task 2 registrierten `SwitchboardJsonContext` — falls beim Build trim-Warnungen zu `HardwareProfile` auftreten, in `SaveAsync`/`TryLoad` `SwitchboardJsonContext.Default.HardwareProfile` verwenden.

- [ ] **Step 4: Run tests to verify they pass**

Run: `dotnet test --filter "FullyQualifiedName~HardwareProfileCacheTests"`
Expected: PASS (alle drei Tests).

- [ ] **Step 5: Commit**

Commit `feat(switchboard): per-install HW-profil-cache mit monats-refresh` (Bulletpoints: ApplicationData-pfad, refresh bei leer/monatswechsel, SemaphoreSlim-serialisiert) + `Ref #268`.

---

## Task 4: HardwareClassifier

**Files:**
- Create: `k.switchboard.net/src/K.Switchboard/Resources/HardwareClassifier.cs`
- Test: `k.switchboard.net/tests/K.Switchboard.Tests/Resources/HardwareClassifierTests.cs`

- [ ] **Step 1: Write the failing test**

Create `Resources/HardwareClassifierTests.cs`:

```csharp
namespace K.Switchboard.Tests.Resources;

using K.Switchboard.Resources;

public sealed class HardwareClassifierTests
{
    private static List<HardwareClassConfig> Classes() =>
    [
        new() { Name = "cpu-low",  Match = new() { MaxRamMb = 16384, GpuVendor = "none" } },
        new() { Name = "gpu-14b",  Match = new() { MinRamMb = 24576, GpuVendor = "NVIDIA", MinVramMb = 10240, MaxVramMb = 16383 } },
    ];

    [Test]
    public async Task Matches_first_class_by_ram_and_vendor()
    {
        var classifier = new HardwareClassifier();
        var profile = new HardwareProfile { TotalRamMb = 15400, Cores = 8, GpuVendor = "none" };

        var match = classifier.Match(profile, Classes());

        await Assert.That(match?.Name).IsEqualTo("cpu-low");
    }

    [Test]
    public async Task Matches_gpu_class_by_vram_range()
    {
        var classifier = new HardwareClassifier();
        var profile = new HardwareProfile { TotalRamMb = 32000, Cores = 16, GpuVendor = "NVIDIA", VramMb = 11264 };

        var match = classifier.Match(profile, Classes());

        await Assert.That(match?.Name).IsEqualTo("gpu-14b");
    }

    [Test]
    public async Task Returns_null_when_no_class_matches()
    {
        var classifier = new HardwareClassifier();
        var profile = new HardwareProfile { TotalRamMb = 20000, Cores = 8, GpuVendor = "AMD", VramMb = 8192 };

        var match = classifier.Match(profile, Classes());

        await Assert.That(match).IsNull();
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dotnet test --filter "FullyQualifiedName~HardwareClassifierTests"`
Expected: COMPILE FAIL — `HardwareClassifier` fehlt.

- [ ] **Step 3: Implement the classifier**

Create `Resources/HardwareClassifier.cs`:

```csharp
namespace K.Switchboard.Resources;

/// <summary>
/// Ordnet ein erkanntes <see cref="HardwareProfile"/> der ersten passenden
/// <see cref="HardwareClassConfig"/> zu. Null-Match-Felder = kein Constraint. Siehe Spec §4.1.
/// </summary>
public sealed class HardwareClassifier
{
    /// <summary>Erste passende Klasse oder null (kein Match).</summary>
    public HardwareClassConfig? Match(HardwareProfile profile, IReadOnlyList<HardwareClassConfig> classes)
    {
        foreach (var c in classes)
        {
            if (Matches(profile, c.Match))
                return c;
        }
        return null;
    }

    private static bool Matches(HardwareProfile p, HardwareClassMatch m)
    {
        if (m.MinRamMb is { } minRam && p.TotalRamMb < minRam) return false;
        if (m.MaxRamMb is { } maxRam && p.TotalRamMb > maxRam) return false;
        if (m.MinCores is { } minCores && p.Cores < minCores) return false;
        if (m.GpuVendor is { } vendor && !string.Equals(vendor, p.GpuVendor, StringComparison.OrdinalIgnoreCase)) return false;
        if (m.MinVramMb is { } minVram && p.VramMb < minVram) return false;
        if (m.MaxVramMb is { } maxVram && p.VramMb > maxVram) return false;
        return true;
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `dotnet test --filter "FullyQualifiedName~HardwareClassifierTests"`
Expected: PASS (alle drei Tests).

- [ ] **Step 5: Commit**

Commit `feat(switchboard): HW-classifier (profil→klasse-match)` (Bulletpoints: range-match RAM/cores/vendor/vram, erste-passende, null bei kein-match) + `Ref #268`.

---

## Task 5: LiveResourceProbe (freier RAM, CPU-Last, Ollama-Warmth)

**Files:**
- Create: `k.switchboard.net/src/K.Switchboard/Resources/LiveResourceSnapshot.cs`
- Create: `k.switchboard.net/src/K.Switchboard/Resources/ICpuLoadSampler.cs`
- Create: `k.switchboard.net/src/K.Switchboard/Resources/CpuLoadSampler.cs`
- Create: `k.switchboard.net/src/K.Switchboard/Resources/ILiveResourceProbe.cs`
- Create: `k.switchboard.net/src/K.Switchboard/Resources/LiveResourceProbe.cs`
- Test: `k.switchboard.net/tests/K.Switchboard.Tests/Resources/LiveResourceProbeTests.cs`

> **Design (Spec §3.3):** Freier RAM ist der primäre, robuste Maschinenschutz (#251-Ursache war RAM→Swapping). Er kommt aus `GC.GetGCMemoryInfo()` (`TotalAvailableMemoryBytes − MemoryLoadBytes`, trim-safe, systemweit). CPU-Last ist sekundär und kommt aus `ICpuLoadSampler` (MVP: Linux `/proc/stat`, sonst nicht-blockierend `0`; robustere Messung in Ausbau +1). Warmth = ist der Modellname in Ollama `/api/ps`.

- [ ] **Step 1: Write the failing test**

Create `Resources/LiveResourceProbeTests.cs`. Nutzt `MockHttpHandler` + `SingleClientFactory` aus `TestHelpers.cs` und einen Fake-CPU-Sampler:

```csharp
namespace K.Switchboard.Tests.Resources;

using K.Switchboard.Resources;

public sealed class LiveResourceProbeTests
{
    private sealed class FakeCpuSampler(double load) : ICpuLoadSampler
    {
        public Task<double> SampleAsync(int windowSeconds, CancellationToken ct) => Task.FromResult(load);
    }

    private static LiveResourceProbe Build(double cpuLoad, string apsBody)
    {
        var handler = new MockHttpHandler(responseBody: apsBody);
        var factory = new SingleClientFactory(new HttpClient(handler) { BaseAddress = new Uri("http://localhost:11434") });
        var opts = new FakeOptionsMonitor<SwitchboardOptions>(new SwitchboardOptions());
        return new LiveResourceProbe(factory, new FakeCpuSampler(cpuLoad), opts,
            Microsoft.Extensions.Logging.Abstractions.NullLogger<LiveResourceProbe>.Instance);
    }

    [Test]
    public async Task Reports_warm_model_from_api_ps()
    {
        var probe = Build(10.0, """{"models":[{"name":"qwen2.5-coder:14b"}]}""");

        var snap = await probe.SampleAsync("qwen2.5-coder:14b", 4, CancellationToken.None);

        await Assert.That(snap.ModelWarm).IsTrue();
        await Assert.That(snap.CpuLoadPercent).IsEqualTo(10.0);
        await Assert.That(snap.FreeRamMb).IsGreaterThanOrEqualTo(0);
    }

    [Test]
    public async Task Reports_cold_model_when_absent_from_api_ps()
    {
        var probe = Build(50.0, """{"models":[]}""");

        var snap = await probe.SampleAsync("qwen2.5-coder:14b", 4, CancellationToken.None);

        await Assert.That(snap.ModelWarm).IsFalse();
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dotnet test --filter "FullyQualifiedName~LiveResourceProbeTests"`
Expected: COMPILE FAIL — Typen fehlen.

- [ ] **Step 3: Implement snapshot + cpu sampler**

Create `Resources/LiveResourceSnapshot.cs`:

```csharp
namespace K.Switchboard.Resources;

/// <summary>Billige Live-Messung pro Request (Spec §3.3).</summary>
public sealed record LiveResourceSnapshot
{
    /// <summary>Aktuell freier System-RAM in MB.</summary>
    public int FreeRamMb { get; init; }

    /// <summary>CPU-Last in Prozent (rollender Mittelwert).</summary>
    public double CpuLoadPercent { get; init; }

    /// <summary>Ist das Zielmodell bereits in Ollama geladen (warm)?</summary>
    public bool ModelWarm { get; init; }
}
```

Create `Resources/ICpuLoadSampler.cs`:

```csharp
namespace K.Switchboard.Resources;

/// <summary>Liefert die System-CPU-Last (%) als rollenden Mittelwert über ein kurzes Fenster.</summary>
public interface ICpuLoadSampler
{
    /// <summary>Mittlere CPU-Last (0–100) über <paramref name="windowSeconds"/>.</summary>
    Task<double> SampleAsync(int windowSeconds, CancellationToken ct);
}
```

Create `Resources/CpuLoadSampler.cs`:

```csharp
namespace K.Switchboard.Resources;

using System.Globalization;
using System.Runtime.InteropServices;

/// <summary>
/// MVP-CPU-Last: Linux via zwei /proc/stat-Snapshots (Delta); andere Plattformen
/// liefern 0 (nicht-blockierend) — robustere Messung folgt in Ausbau +1.
/// </summary>
public sealed class CpuLoadSampler : ICpuLoadSampler
{
    public async Task<double> SampleAsync(int windowSeconds, CancellationToken ct)
    {
        if (!RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
            return 0.0;

        var sampleMs = Math.Clamp(windowSeconds, 1, 10) * 1000;
        var (idle1, total1) = ReadProcStat();
        await Task.Delay(Math.Min(sampleMs, 1000), ct);   // kurzes Fenster, max 1s Blockade
        var (idle2, total2) = ReadProcStat();

        var totalDelta = total2 - total1;
        var idleDelta = idle2 - idle1;
        if (totalDelta <= 0) return 0.0;
        return Math.Clamp(100.0 * (totalDelta - idleDelta) / totalDelta, 0, 100);
    }

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
}
```

- [ ] **Step 4: Implement the probe**

Create `Resources/ILiveResourceProbe.cs`:

```csharp
namespace K.Switchboard.Resources;

/// <summary>Billige Live-Ressourcen-Messung pro Request.</summary>
public interface ILiveResourceProbe
{
    /// <summary>Misst freien RAM, CPU-Last und ob <paramref name="model"/> in Ollama warm ist.</summary>
    Task<LiveResourceSnapshot> SampleAsync(string model, int cpuWindowSeconds, CancellationToken ct);
}
```

Create `Resources/LiveResourceProbe.cs`:

```csharp
namespace K.Switchboard.Resources;

using System.Text.Json;

/// <summary>
/// Freier RAM via GC-MemoryInfo (trim-safe); CPU-Last via <see cref="ICpuLoadSampler"/>;
/// Warmth via Ollama <c>/api/ps</c>. Alle Reads sind billig und best-effort (Fehler ⇒ neutraler Wert).
/// </summary>
public sealed class LiveResourceProbe(
    IHttpClientFactory httpFactory,
    ICpuLoadSampler cpuSampler,
    IOptionsMonitor<SwitchboardOptions> options,
    ILogger<LiveResourceProbe> logger) : ILiveResourceProbe
{
    public async Task<LiveResourceSnapshot> SampleAsync(string model, int cpuWindowSeconds, CancellationToken ct)
    {
        var info = GC.GetGCMemoryInfo();
        var freeBytes = info.TotalAvailableMemoryBytes - info.MemoryLoadBytes;
        var freeRamMb = (int)(Math.Max(0, freeBytes) / (1024 * 1024));

        var cpu = await cpuSampler.SampleAsync(cpuWindowSeconds, ct);
        var warm = await IsWarmAsync(model, ct);

        return new LiveResourceSnapshot { FreeRamMb = freeRamMb, CpuLoadPercent = cpu, ModelWarm = warm };
    }

    private async Task<bool> IsWarmAsync(string model, CancellationToken ct)
    {
        try
        {
            var client = httpFactory.CreateClient("ollama");
            var baseUrl = options.CurrentValue.OllamaBaseUrl.TrimEnd('/');
            using var resp = await client.GetAsync($"{baseUrl}/api/ps", ct);
            if (!resp.IsSuccessStatusCode) return false;
            var json = await resp.Content.ReadAsStringAsync(ct);
            using var doc = JsonDocument.Parse(json);
            if (!doc.RootElement.TryGetProperty("models", out var models)) return false;
            foreach (var m in models.EnumerateArray())
            {
                if (m.TryGetProperty("name", out var name)
                    && string.Equals(name.GetString(), model, StringComparison.OrdinalIgnoreCase))
                    return true;
            }
            return false;
        }
        catch (Exception ex)
        {
            logger.LogDebug(ex, "Ollama /api/ps nicht erreichbar — Modell als kalt gewertet.");
            return false;
        }
    }
}
```

> **Test-Hinweis:** Der `MockHttpHandler` ignoriert die URL und liefert immer `responseBody` — daher genügt der gesetzte Body. `BaseAddress` am `HttpClient` ist im Test nur Formsache, der absolute `GetAsync`-URL-Aufbau funktioniert mit dem Mock.

- [ ] **Step 5: Run tests to verify they pass**

Run: `dotnet test --filter "FullyQualifiedName~LiveResourceProbeTests"`
Expected: PASS (beide Tests).

- [ ] **Step 6: Commit**

Commit `feat(switchboard): live-resource-probe (RAM/CPU/warmth)` (Bulletpoints: freier RAM via GC-memoryinfo, ICpuLoadSampler linux/proc-stat, ollama /api/ps warmth, best-effort) + `Ref #268`.

---

## Task 6: RoutingDecision + ResourceGate (Kern-Entscheidung)

**Files:**
- Create: `k.switchboard.net/src/K.Switchboard/Resources/RoutingDecision.cs`
- Create: `k.switchboard.net/src/K.Switchboard/Resources/ResourceGate.cs`
- Test: `k.switchboard.net/tests/K.Switchboard.Tests/Resources/ResourceGateTests.cs`

> **Entscheidungsregel (Spec §2, §7).** `EvaluateAsync(requestedModel)`:
> 1. Gate aus (`Enabled=false`) → **Proceed** mit Original-Modell (kein Header).
> 2. Resolve; Provider ≠ `ollama` → **Proceed** (Original, kein Header) — Gate ist no-op für nicht-lokale Modelle.
> 3. Lokales Modell: Profil (Cache) → Klasse (Classifier) → `ModelValidation`. Nur wenn `PeakRamMb > 0` (explizit validiert) ist lokaler Lauf überhaupt zulässig.
>    - Admission: `freier RAM ≥ PeakRamMb + Buffer` **und** `CPU-Last ≤ CpuMaxLoadPercent` → **Proceed** (Original).
>    - Sonst (oder kein validiertes Footprint) → Substitutions-Priorität:
>      1. `FallbackChains[requestedModel]` gesetzt → **Proceed** mit erstem Chain-Glied + Header (`deferred`).
>      2. `LocalModelTiers[model]`→`TierSubstitutions[tier]` vorhanden → **Proceed** mit Claude-Modell + Header (`substitution`).
>      3. nichts davon → **Fail** (HTTP 503 + Log).
>
> Buffer-Default bei `RamBufferMb=0`: `max(1024, PeakRamMb / 4)` (im Eval kalibrierbar, Spec §5). **MVP-Vereinfachung:** „Defer-to-Fallback" nutzt nur das *erste* Chain-Glied als effektives Modell (mehrgliedrige Restkette nach Defer → Ausbau +1).

- [ ] **Step 1: Write the failing test**

Create `Resources/ResourceGateTests.cs`:

```csharp
namespace K.Switchboard.Tests.Resources;

using K.Switchboard.Resources;

public sealed class ResourceGateTests
{
    private sealed class FakeProbe(LiveResourceSnapshot snap) : ILiveResourceProbe
    {
        public Task<LiveResourceSnapshot> SampleAsync(string model, int cpuWindowSeconds, CancellationToken ct)
            => Task.FromResult(snap);
    }

    private sealed class FixedDetector(HardwareProfile p) : IHardwareProfileDetector
    {
        public Task<HardwareProfile> DetectAsync(CancellationToken ct)
            => Task.FromResult(p with { DetectedOn = DateTimeOffset.UtcNow });
    }

    private static ResourceGate Build(
        LiveResourceSnapshot snap,
        HardwareProfile profile,
        bool enabled = true,
        Dictionary<string, List<string>>? fallbacks = null)
    {
        var opts = new SwitchboardOptions
        {
            ResourceGate = new ResourceGateOptions { Enabled = enabled, CpuMaxLoadPercent = 85 },
            ModelAliases = new() { ["local-coder"] = "qwen2.5-coder:14b" },
            LocalModelTiers = new() { ["qwen2.5-coder:14b"] = "L" },
            TierSubstitutions = new() { ["L"] = "claude-sonnet-4-6" },
            FallbackChains = fallbacks ?? new(),
            HardwareClasses =
            [
                new()
                {
                    Name = "gpu-14b",
                    Match = new() { GpuVendor = "NVIDIA", MinVramMb = 10240 },
                    Models = new() { ["qwen2.5-coder:14b"] = new ModelValidation { PeakRamMb = 11000, ValidatedOn = "rig" } }
                }
            ]
        };
        var optsMon = new FakeOptionsMonitor<SwitchboardOptions>(opts);
        var router = new ModelRouter(optsMon);
        var tmp = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
        Directory.CreateDirectory(tmp);
        var cache = new HardwareProfileCache(new FixedDetector(profile), tmp,
            Microsoft.Extensions.Logging.Abstractions.NullLogger<HardwareProfileCache>.Instance);
        return new ResourceGate(router, cache, new HardwareClassifier(), new FakeProbe(snap), optsMon,
            Microsoft.Extensions.Logging.Abstractions.NullLogger<ResourceGate>.Instance);
    }

    private static readonly HardwareProfile Gpu14b =
        new() { TotalRamMb = 32000, Cores = 16, GpuVendor = "NVIDIA", VramMb = 11264 };

    [Test]
    public async Task Admits_local_when_enough_ram_and_low_cpu()
    {
        var gate = Build(new LiveResourceSnapshot { FreeRamMb = 20000, CpuLoadPercent = 10, ModelWarm = true }, Gpu14b);

        var d = await gate.EvaluateAsync("local-coder", CancellationToken.None);

        await Assert.That(d.Action).IsEqualTo(RoutingAction.Proceed);
        await Assert.That(d.EffectiveModel).IsEqualTo("local-coder");
        await Assert.That(d.SubstitutionHeader).IsNull();
    }

    [Test]
    public async Task Substitutes_to_claude_when_ram_too_low()
    {
        var gate = Build(new LiveResourceSnapshot { FreeRamMb = 2000, CpuLoadPercent = 10 }, Gpu14b);

        var d = await gate.EvaluateAsync("local-coder", CancellationToken.None);

        await Assert.That(d.Action).IsEqualTo(RoutingAction.Proceed);
        await Assert.That(d.EffectiveModel).IsEqualTo("claude-sonnet-4-6");
        await Assert.That(d.SubstitutionHeader).IsNotNull();
    }

    [Test]
    public async Task Substitutes_when_cpu_overloaded()
    {
        var gate = Build(new LiveResourceSnapshot { FreeRamMb = 20000, CpuLoadPercent = 95 }, Gpu14b);

        var d = await gate.EvaluateAsync("local-coder", CancellationToken.None);

        await Assert.That(d.EffectiveModel).IsEqualTo("claude-sonnet-4-6");
    }

    [Test]
    public async Task Defers_to_explicit_fallback_chain_before_substitution()
    {
        var gate = Build(
            new LiveResourceSnapshot { FreeRamMb = 2000, CpuLoadPercent = 10 }, Gpu14b,
            fallbacks: new() { ["local-coder"] = ["claude-opus-4-8"] });

        var d = await gate.EvaluateAsync("local-coder", CancellationToken.None);

        await Assert.That(d.EffectiveModel).IsEqualTo("claude-opus-4-8");   // Chain-Glied, nicht Tier-Substitut
        await Assert.That(d.SubstitutionHeader).IsNotNull();
    }

    [Test]
    public async Task Fails_5xx_when_no_substitute_and_no_fallback()
    {
        // Profil ohne validiertes Footprint (cpu-only) → keine lokale Ausführung; Tier ohne Eintrag
        var opts = new SwitchboardOptions
        {
            ResourceGate = new ResourceGateOptions { Enabled = true },
            ModelAliases = new() { ["local-coder"] = "qwen2.5-coder:14b" },
            HardwareClasses = []   // kein Match → kein Footprint
        };
        var optsMon = new FakeOptionsMonitor<SwitchboardOptions>(opts);
        var tmp = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
        Directory.CreateDirectory(tmp);
        var cache = new HardwareProfileCache(
            new FixedDetector(new HardwareProfile { TotalRamMb = 15400, Cores = 8, GpuVendor = "none" }), tmp,
            Microsoft.Extensions.Logging.Abstractions.NullLogger<HardwareProfileCache>.Instance);
        var gate = new ResourceGate(new ModelRouter(optsMon), cache, new HardwareClassifier(),
            new FakeProbe(new LiveResourceSnapshot { FreeRamMb = 1000, CpuLoadPercent = 50 }), optsMon,
            Microsoft.Extensions.Logging.Abstractions.NullLogger<ResourceGate>.Instance);

        var d = await gate.EvaluateAsync("local-coder", CancellationToken.None);

        await Assert.That(d.Action).IsEqualTo(RoutingAction.Fail);
        await Assert.That(d.FailStatusCode).IsGreaterThanOrEqualTo(500);
    }

    [Test]
    public async Task Proceeds_unchanged_when_gate_disabled()
    {
        var gate = Build(new LiveResourceSnapshot { FreeRamMb = 100, CpuLoadPercent = 99 }, Gpu14b, enabled: false);

        var d = await gate.EvaluateAsync("local-coder", CancellationToken.None);

        await Assert.That(d.Action).IsEqualTo(RoutingAction.Proceed);
        await Assert.That(d.EffectiveModel).IsEqualTo("local-coder");
    }
}
```

> **Vorab prüfen:** `ModelRouter.Resolve("qwen2.5-coder:14b")` muss `("ollama", "qwen2.5-coder:14b")` liefern (':'-Heuristik). Falls der Router Aliase anders auflöst, Test-Aliase/Erwartung anpassen — `Routing/ModelRouter.cs` lesen.

- [ ] **Step 2: Run test to verify it fails**

Run: `dotnet test --filter "FullyQualifiedName~ResourceGateTests"`
Expected: COMPILE FAIL — `RoutingDecision`, `RoutingAction`, `ResourceGate` fehlen.

- [ ] **Step 3: Implement RoutingDecision**

Create `Resources/RoutingDecision.cs`:

```csharp
namespace K.Switchboard.Resources;

/// <summary>Resultat-Aktion des ResourceGate.</summary>
public enum RoutingAction
{
    /// <summary>Mit <see cref="RoutingDecision.EffectiveModel"/> weiter an FallbackService.</summary>
    Proceed,

    /// <summary>Hart abbrechen mit <see cref="RoutingDecision.FailStatusCode"/>.</summary>
    Fail
}

/// <summary>Strukturierte Routing-Entscheidung (Spec §3.7). Speist Log + Response-Header.</summary>
public sealed record RoutingDecision
{
    /// <summary>Proceed oder Fail.</summary>
    public RoutingAction Action { get; init; }

    /// <summary>Modell, mit dem FallbackService startet (leer bei Fail).</summary>
    public string EffectiveModel { get; init; } = string.Empty;

    /// <summary>Menschlich lesbarer Grund (Log).</summary>
    public string Reason { get; init; } = string.Empty;

    /// <summary>Wert für den Header <c>X-K-Switchboard-Substitution</c>; null = kein Header.</summary>
    public string? SubstitutionHeader { get; init; }

    /// <summary>HTTP-Status bei <see cref="RoutingAction.Fail"/>.</summary>
    public int FailStatusCode { get; init; } = 503;
}
```

- [ ] **Step 4: Implement ResourceGate**

Create `Resources/ResourceGate.cs`:

```csharp
namespace K.Switchboard.Resources;

using K.Switchboard.Routing;

/// <summary>
/// Pre-flight-Gate VOR dem FallbackService (Spec §2). Prüft nur das primär angefragte Modell:
/// lokal ausführbar → Proceed; sonst Defer-to-Fallback / Tier-Substitution / Fail.
/// </summary>
public sealed class ResourceGate(
    ModelRouter router,
    HardwareProfileCache cache,
    HardwareClassifier classifier,
    ILiveResourceProbe probe,
    IOptionsMonitor<SwitchboardOptions> options,
    ILogger<ResourceGate> logger)
{
    public async Task<RoutingDecision> EvaluateAsync(string requestedModel, CancellationToken ct)
    {
        var opts = options.CurrentValue;
        if (!opts.ResourceGate.Enabled)
            return Proceed(requestedModel, "gate-disabled");

        var (providerName, resolvedModel) = router.Resolve(requestedModel);
        if (!string.Equals(providerName, "ollama", StringComparison.OrdinalIgnoreCase))
            return Proceed(requestedModel, "non-local-provider");

        var profile = await cache.GetAsync(ct);
        var hwClass = classifier.Match(profile, opts.HardwareClasses);
        var validation = hwClass is not null && hwClass.Models.TryGetValue(resolvedModel, out var v) ? v : null;

        if (validation is { PeakRamMb: > 0 })
        {
            var buffer = opts.ResourceGate.RamBufferMb > 0
                ? opts.ResourceGate.RamBufferMb
                : Math.Max(1024, validation.PeakRamMb / 4);
            var need = validation.PeakRamMb + buffer;
            var live = await probe.SampleAsync(resolvedModel, opts.ResourceGate.CpuLoadWindowSeconds, ct);

            if (live.FreeRamMb >= need && live.CpuLoadPercent <= opts.ResourceGate.CpuMaxLoadPercent)
            {
                logger.LogInformation(
                    "ResourceGate: lokal zugelassen {Model} (frei {Free}MB ≥ {Need}MB, CPU {Cpu}%, warm={Warm})",
                    resolvedModel, live.FreeRamMb, need, live.CpuLoadPercent, live.ModelWarm);
                return Proceed(requestedModel, $"local-admitted free={live.FreeRamMb}MB warm={live.ModelWarm}");
            }

            return BuildSubstitution(requestedModel, resolvedModel, opts,
                $"free {live.FreeRamMb}MB/{need}MB, CPU {live.CpuLoadPercent:F0}%");
        }

        return BuildSubstitution(requestedModel, resolvedModel, opts,
            hwClass is null ? "no matching hardware class" : "no validated footprint");
    }

    private RoutingDecision BuildSubstitution(string requestedModel, string localModel, SwitchboardOptions opts, string reason)
    {
        // 1) Explizite Fallback-Kette hat Vorrang (Nutzer-konfiguriert).
        if (opts.FallbackChains.TryGetValue(requestedModel, out var chain) && chain.Count > 0)
        {
            var target = chain[0];
            var header = $"{localModel} -> {target} (deferred: {reason})";
            logger.LogInformation("ResourceGate: defer-to-fallback {Header}", header);
            return new RoutingDecision { Action = RoutingAction.Proceed, EffectiveModel = target, Reason = reason, SubstitutionHeader = header };
        }

        // 2) Tier-Substitution.
        if (opts.LocalModelTiers.TryGetValue(localModel, out var tier)
            && opts.TierSubstitutions.TryGetValue(tier, out var claude))
        {
            var header = $"{claude} (local {localModel} not viable — {reason})";
            logger.LogInformation("ResourceGate: substitution {Header}", header);
            return new RoutingDecision { Action = RoutingAction.Proceed, EffectiveModel = claude, Reason = reason, SubstitutionHeader = header };
        }

        // 3) Kein Fallback, kein Substitut → hart fehlschlagen.
        logger.LogWarning("ResourceGate: kein Fallback/Substitut für {Model} ({Reason}) → 503", localModel, reason);
        return new RoutingDecision { Action = RoutingAction.Fail, Reason = reason, FailStatusCode = StatusCodes.Status503ServiceUnavailable };
    }

    private static RoutingDecision Proceed(string model, string reason)
        => new() { Action = RoutingAction.Proceed, EffectiveModel = model, Reason = reason };
}
```

> **Hinweis:** `StatusCodes` kommt aus `Microsoft.AspNetCore.Http` — bereits via GlobalUsings im Projekt verfügbar (siehe `FallbackService.cs`). Falls nicht aufgelöst: `using Microsoft.AspNetCore.Http;` ergänzen.

- [ ] **Step 5: Run tests to verify they pass**

Run: `dotnet test --filter "FullyQualifiedName~ResourceGateTests"`
Expected: PASS (alle sechs Tests).

- [ ] **Step 6: Commit**

Commit `feat(switchboard): ResourceGate kern-entscheidung` (Bulletpoints: admission RAM+CPU, defer-to-fallback vor tier-substitution, 503 ohne option, RoutingDecision-record für log+header) + `Ref #268`.

---

## Task 7: Blast-Radius-Cap im OllamaProvider

**Files:**
- Create: `k.switchboard.net/src/K.Switchboard/Resources/LocalInferenceGate.cs`
- Modify: `k.switchboard.net/src/K.Switchboard/Providers/OllamaProvider.cs`
- Test: `k.switchboard.net/tests/K.Switchboard.Tests/Resources/OllamaBlastRadiusTests.cs`

> **Ziel (Spec §3.6):** (1) `num_thread = Kerne−2` (min 2) in den Ollama-`options`; (2) `SemaphoreSlim(1)`-Serialisierung lokaler Inferenz. Watchdog (Timeout) ist über `OllamaTimeoutSeconds`/#252 bereits vorhanden.

- [ ] **Step 1: LocalInferenceGate (Singleton-Semaphore)**

Create `Resources/LocalInferenceGate.cs`:

```csharp
namespace K.Switchboard.Resources;

/// <summary>Serialisiert lokale Inferenz: nie zwei gleichzeitige Ollama-Läufe (Spec §3.6.2).</summary>
public sealed class LocalInferenceGate : IDisposable
{
    private readonly SemaphoreSlim _semaphore = new(1, 1);

    /// <summary>Belegt den Slot; das zurückgegebene <see cref="IDisposable"/> gibt ihn frei.</summary>
    public async Task<IDisposable> AcquireAsync(CancellationToken ct)
    {
        await _semaphore.WaitAsync(ct);
        return new Releaser(_semaphore);
    }

    public void Dispose() => _semaphore.Dispose();

    private sealed class Releaser(SemaphoreSlim sem) : IDisposable
    {
        private int _released;
        public void Dispose()
        {
            if (Interlocked.Exchange(ref _released, 1) == 0)
                sem.Release();
        }
    }
}
```

- [ ] **Step 2: Write the failing test (num_thread in body)**

The `num_thread`-Wert wird aus den verfügbaren Kernen abgeleitet. Damit das testbar ist, nimmt `BuildOllamaBodyAsync` einen `int numThread`-Parameter. Create `Resources/OllamaBlastRadiusTests.cs`:

```csharp
namespace K.Switchboard.Tests.Resources;

using System.Text.Json.Nodes;
using K.Switchboard.Providers;

public sealed class OllamaBlastRadiusTests
{
    [Test]
    public async Task Sets_num_thread_in_options()
    {
        using var bodyStream = new MemoryStream(
            System.Text.Encoding.UTF8.GetBytes("""{"model":"x","messages":[],"max_tokens":256}"""));

        var (body, _) = await OllamaProvider.BuildOllamaBodyForTest(bodyStream, "qwen2.5-coder:14b", "30m", numThread: 6, CancellationToken.None);

        var options = body["options"] as JsonObject;
        await Assert.That(options).IsNotNull();
        await Assert.That(options!["num_thread"]!.GetValue<int>()).IsEqualTo(6);
        await Assert.That(options["num_predict"]!.GetValue<int>()).IsEqualTo(256);
    }

    [Test]
    public async Task Num_thread_present_even_without_max_tokens()
    {
        using var bodyStream = new MemoryStream(
            System.Text.Encoding.UTF8.GetBytes("""{"model":"x","messages":[]}"""));

        var (body, _) = await OllamaProvider.BuildOllamaBodyForTest(bodyStream, "m", "30m", numThread: 4, CancellationToken.None);

        var options = body["options"] as JsonObject;
        await Assert.That(options!["num_thread"]!.GetValue<int>()).IsEqualTo(4);
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `dotnet test --filter "FullyQualifiedName~OllamaBlastRadiusTests"`
Expected: COMPILE FAIL — `BuildOllamaBodyForTest` / `numThread`-Parameter fehlen.

- [ ] **Step 4: Add num_thread to BuildOllamaBodyAsync**

In `Providers/OllamaProvider.cs`:

1. Signatur von `BuildOllamaBodyAsync` (Zeile 61) um `int numThread` erweitern:

```csharp
    private static async Task<(JsonObject Body, bool IsStreaming)> BuildOllamaBodyAsync(
        Stream body, string resolvedModel, string keepAlive, int numThread, CancellationToken ct)
```

2. Den `options`-Block (Zeile 96–99) ersetzen, sodass `options` IMMER existiert und `num_thread` enthält:

```csharp
        var optionsObj = new JsonObject { ["num_thread"] = numThread };
        if (request["max_tokens"]?.GetValue<int?>() is int maxTokens)
            optionsObj["num_predict"] = maxTokens;
        ollamaBody["options"] = optionsObj;
```

3. Am Aufrufort von `BuildOllamaBodyAsync` (in `ForwardAsync`, ~Zeile 24-ff.) den `numThread` aus den Kernen berechnen und übergeben:

```csharp
        var numThread = Math.Max(2, Environment.ProcessorCount - 2);
        var (ollamaBody, isStreaming) = await BuildOllamaBodyAsync(context.Request.Body, resolvedModel, opts.OllamaKeepAlive, numThread, ct);
```

(Den genauen bestehenden Aufruf in `ForwardAsync` lesen und 1:1 um den Parameter ergänzen — `opts`/keepAlive-Quelle beibehalten.)

4. Test-Hook (internal, am Ende der Klasse) für den privaten Builder:

```csharp
    /// <summary>Nur für Tests: macht den privaten Body-Builder zugänglich.</summary>
    internal static Task<(JsonObject Body, bool IsStreaming)> BuildOllamaBodyForTest(
        Stream body, string resolvedModel, string keepAlive, int numThread, CancellationToken ct)
        => BuildOllamaBodyAsync(body, resolvedModel, keepAlive, numThread, ct);
```

Sicherstellen, dass das Test-Projekt `InternalsVisibleTo` hat. Falls nicht: in `K.Switchboard.csproj` ergänzen:

```xml
  <ItemGroup>
    <InternalsVisibleTo Include="K.Switchboard.Tests" />
  </ItemGroup>
```

- [ ] **Step 5: Serialize local inference**

`LocalInferenceGate` per DI in `OllamaProvider` injizieren (ctor-Parameter ergänzen). In `ForwardAsync` den eigentlichen Upstream-Call (Ollama `SendAsync` + Response-Schreiben) umschließen:

```csharp
        using var _ = await localGate.AcquireAsync(ct);
        // ... bestehender Ollama-Call + Response-Handling ...
```

(Den Acquire möglichst eng um den Inferenz-Call legen, nicht um die Body-Transformation.)

- [ ] **Step 6: Run tests + full build**

Run: `dotnet test --filter "FullyQualifiedName~OllamaBlastRadiusTests"` → PASS.
Run: `dotnet build` → keine neuen Warnungen/Fehler.

- [ ] **Step 7: Commit**

Commit `feat(switchboard): blast-radius-cap im OllamaProvider` (Bulletpoints: num_thread=Kerne-2 in options, LocalInferenceGate SemaphoreSlim serialisiert lokale inferenz, InternalsVisibleTo für test-hook) + `Ref #268`.

---

## Task 8: DI-Verdrahtung + Endpoint-Integration + Default-Config

**Files:**
- Modify: `k.switchboard.net/src/K.Switchboard/Program.cs`
- Modify: Default-Config-Quelle (`k.switchboard.net/src/K.Switchboard/Program.cs` Seed-Block ~Z. 24–43 **oder** `appsettings.json` — die beim Build mitgelieferte Default-Config; vor Ort prüfen)
- Modify: `.gitignore` (Repo-Root)
- Test: `k.switchboard.net/tests/K.Switchboard.Tests/Integration/ResourceGateEndpointTests.cs`

- [ ] **Step 1: Register services (DI)**

In `Program.cs` nach der Provider/Routing-Region (nach Zeile 122, `AddSingleton<ModelRouter>()`) ergänzen:

```csharp
    // --- ResourceGate (Pre-flight Ressourcen-Check, Phase 3.5) ---
    builder.Services.AddSingleton<K.Switchboard.Resources.IProcessRunner, K.Switchboard.Resources.ProcessRunner>();
    builder.Services.AddSingleton<K.Switchboard.Resources.IHardwareProfileDetector, K.Switchboard.Resources.HardwareProfileDetector>();
    builder.Services.AddSingleton<K.Switchboard.Resources.HardwareProfileCache>();
    builder.Services.AddSingleton<K.Switchboard.Resources.HardwareClassifier>();
    builder.Services.AddSingleton<K.Switchboard.Resources.ICpuLoadSampler, K.Switchboard.Resources.CpuLoadSampler>();
    builder.Services.AddSingleton<K.Switchboard.Resources.ILiveResourceProbe, K.Switchboard.Resources.LiveResourceProbe>();
    builder.Services.AddSingleton<K.Switchboard.Resources.LocalInferenceGate>();
    builder.Services.AddSingleton<K.Switchboard.Resources.ResourceGate>();
```

(Optional ein `using K.Switchboard.Resources;` oben ergänzen und die Präfixe weglassen — dem bestehenden Stil folgen.)

- [ ] **Step 2: Call the gate in the endpoint**

Im `POST /v1/messages`-Handler (Zeile 143): `ResourceGate` als Parameter ergänzen und NACH dem `requestedModel`-Parsing (nach Zeile 170, vor dem `fallback.ForwardWithFallbackAsync`-Aufruf) einhängen.

Signatur erweitern:

```csharp
    app.MapPost("/v1/messages", async (HttpContext ctx, ModelRouter router, FallbackService fallback,
        K.Switchboard.Resources.ResourceGate gate, IOptionsSnapshot<SwitchboardOptions> options, CancellationToken ct) =>
```

Nach erfolgreichem `requestedModel`-Parse, vor dem bestehenden `ForwardWithFallbackAsync`:

```csharp
        var decision = await gate.EvaluateAsync(requestedModel, ct);
        if (decision.Action == K.Switchboard.Resources.RoutingAction.Fail)
        {
            ctx.Response.StatusCode = decision.FailStatusCode;
            await ctx.Response.WriteAsJsonAsync(new ProblemDetails
            {
                Title = "Local model not viable",
                Detail = $"No fallback or substitute available — {decision.Reason}."
            },
            SwitchboardJsonContext.Default.ProblemDetails, cancellationToken: ct);
            return;
        }
        if (decision.SubstitutionHeader is { } sub)
            ctx.Response.Headers["X-K-Switchboard-Substitution"] = sub;
```

Den bestehenden `ForwardWithFallbackAsync`-Aufruf so ändern, dass er `decision.EffectiveModel` statt `requestedModel` nutzt:

```csharp
        await fallback.ForwardWithFallbackAsync(ctx, decision.EffectiveModel, ct);
```

(Den genauen bestehenden Aufruf lesen und nur das Modell-Argument tauschen.)

- [ ] **Step 3: Seed committed default config (Mapping b + Substitution)**

Die ausgelieferte Default-Config um die kuratierten Sektionen erweitern (datenbasiert, Spec §4). `peakRamMb: 0` = noch nicht gemessen → wird in Task 9 für die reale Klasse gefüllt; 0 bedeutet „nicht lokal ausführen → substituieren" (sicher):

```jsonc
"LocalModelTiers": {
  "qwen2.5-coder:1.5b": "S", "llama3.2:3b": "S",
  "qwen2.5-coder:7b": "M", "llama3.1:8b": "M",
  "qwen2.5-coder:14b": "L", "qwen2.5-coder:32b": "L"
},
"TierSubstitutions": { "S": "claude-haiku-4-5", "M": "claude-sonnet-4-6", "L": "claude-sonnet-4-6" },
"ResourceGate": { "enabled": true, "ramBufferMb": 0, "cpuLoadWindowSeconds": 4, "cpuMaxLoadPercent": 85 },
"HardwareClasses": [
  { "name": "cpu-low",       "match": { "maxRamMb": 16384, "gpuVendor": "none" }, "models": {} },
  { "name": "cpu-32",        "match": { "minRamMb": 24576, "gpuVendor": "none" }, "models": {} },
  { "name": "gpu-7b",        "match": { "minVramMb": 6144,  "maxVramMb": 10239 }, "models": {} },
  { "name": "gpu-14b",       "match": { "minVramMb": 10240, "maxVramMb": 16383 }, "models": {} },
  { "name": "gpu-14b-plus",  "match": { "minVramMb": 16384 }, "models": {} }
]
```

> **Hinweis:** `cpu-32` ohne VRAM-Constraint matcht auch 32-GB-Maschinen mit schwacher GPU (GTX 970 = 3,5 GB < 6144 → keine `gpu-*`-Klasse greift, da deren `minVramMb` nicht erreicht wird; Reihenfolge: spezifische GPU-Klassen vor `cpu-32` listen, falls VRAM ausreicht). **Wichtig:** Klassen-Reihenfolge = Match-Priorität. GPU-Klassen VOR `cpu-32` einsortieren, sonst greift `cpu-32` (kein VRAM-Constraint) zuerst. Korrigierte Reihenfolge: `cpu-low`, `gpu-7b`, `gpu-14b`, `gpu-14b-plus`, `cpu-32` (Catch-all zuletzt). Diese Reihenfolge im Seed verwenden.

- [ ] **Step 4: gitignore the per-install cache**

In `.gitignore` (Repo-Root) ergänzen:

```gitignore
# K.Switchboard per-install HW-Profil-Cache (maschinenspezifisch, nie committen)
hw-profile.json
```

- [ ] **Step 5: Write the integration test**

Create `Integration/ResourceGateEndpointTests.cs` nach dem Muster von `Integration/StatsEndpointTests.cs` (dieses zuerst lesen für das `WebApplicationFactory`-/Host-Setup). Test-Config: Gate `enabled`, ein lokales Alias (`local-coder`→`qwen2.5-coder:14b`), `TierSubstitutions L=claude-sonnet-4-6`, leere `HardwareClasses` (→ kein Footprint → Substitution). Sende `POST /v1/messages` mit `{"model":"local-coder",...}` und prüfe:

```csharp
// Erwartung: Response trägt Header X-K-Switchboard-Substitution (lokal nicht viabel → Claude),
// und der Upstream wurde mit dem Claude-Modell aufgerufen (Mock-Anthropic 200).
await Assert.That(response.Headers.Contains("X-K-Switchboard-Substitution")).IsTrue();
```

Zweiter Fall: ohne `TierSubstitutions` und ohne `FallbackChains` → erwarte HTTP 503.

> Falls das volle Host-Setup zu aufwändig ist, genügt für den MVP der Nachweis der Verdrahtung über die bestehenden Unit-Tests (Task 6) + ein Smoke-Test, der den Endpoint mit gemocktem `ResourceGate` aufruft. Dann diesen Schritt entsprechend reduzieren und im Commit vermerken.

- [ ] **Step 6: Build + full test run**

Run: `dotnet build` → grün.
Run: `dotnet test` → alle Tests grün (inkl. bestehende — Regression prüfen, da Endpoint-Signatur geändert).

- [ ] **Step 7: Commit**

Commit `feat(switchboard): ResourceGate in endpoint + DI + default-config` (Bulletpoints: DI-registrierung aller resource-services, gate-aufruf vor FallbackService, X-K-Switchboard-Substitution-header + 503-fail, default-config tiers/substitutions/HW-klassen, hw-profile.json gitignored) + `Ref #268`.

---

## Task 9: Eval-Measurement (Mess-Erweiterung + 1 realer Lauf + Doku)

**Files:**
- Modify: `plugins/kagents/agents/commit-messenger/evals/run-evals.ps1` (und `code-reviewer/evals/run-evals.ps1`)
- Create: `k.switchboard.net/docs/eval-measurement.md`
- Modify: Default-Config `HardwareClasses[*].models` (reale Klasse mit gemessenem `peakRamMb`)

> **Voraussetzung:** Lokales Ollama + die zu messenden Modelle (auf diesem Laptop real: `llama3.2:3b`, `qwen2.5-coder:7b`). Dieser Task braucht lokale Ressourcen/Zeit.

- [ ] **Step 1: Extend run-evals.ps1 with RAM peak + latency**

`run-evals.ps1` misst bereits Latenz (laut README). Ergänze pro Inferenz-Call eine **Peak-RAM-Messung**: vor dem Call den freien RAM lesen, während des Calls (Hintergrund-Sampling, ~250 ms-Intervall) das Minimum-frei tracken, Peak-Verbrauch = Baseline-frei − Min-frei. Cross-platform:

```powershell
# Windows: (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory  (KB)
# Linux:   awk '/MemAvailable/ {print $2}' /proc/meminfo                (KB)
function Get-FreeRamMb {
    if ($IsWindows) { return [int]((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024) }
    elseif ($IsLinux) { return [int]((Select-String -Path /proc/meminfo -Pattern 'MemAvailable:\s+(\d+)').Matches[0].Groups[1].Value / 1024) }
    else { return 0 }   # macOS: vm_stat-Parsing optional, MVP = 0
}
```

Ergänze zusätzlich einen Abruf von Ollama `/api/ps` direkt nach dem Call, um die **geladene Modellgröße** (`size_vram`/`size`) zu protokollieren. Schreibe je Modell/Input: Latenz, Peak-RAM-Delta (MB), geladene Größe. In `results.md`/`runs/<datum>/` festhalten.

- [ ] **Step 2: Run one real measurement pass**

Run (aus `plugins/kagents/agents/commit-messenger/evals/`): `./run-evals.ps1 -Models 'llama3.2:3b'` und `'qwen2.5-coder:7b'`.
Erfasse die realen `peakRamMb`-Werte für die hiesige HW-Klasse (`cpu-low`, 15,4 GB CPU-only). Notiere die Werte.

- [ ] **Step 3: Create eval-measurement.md**

Create `k.switchboard.net/docs/eval-measurement.md` mit: (a) Methodik (welches Skript, welche Fixtures, welches HW-Setup, wie Peak-RAM gemessen wird — reproduzierbar); (b) Mess-Tabelle je Modell/HW-Setup (Peak-RAM, Latenz P50, Score aus #251); (c) **Herleitung des `ramBuffer`-Defaults** aus der Differenz Peak-bei-kleinem- vs. großem-Kontext + OS-Reserve (Spec §5); (d) Verweis: aus `configuration.md` referenziert. Klar markieren, welche Werte **gemessen** und welche **konservative Defaults** (nicht gemessen) sind.

- [ ] **Step 4: Backfill measured peakRamMb into default config**

Trage die in Step 2 gemessenen `peakRamMb`/`validatedOn`/`latencyP50Ms` für die reale Klasse in die Default-Config `HardwareClasses[*].models` ein. **Wichtig (Spec/#251):** Auf `cpu-low` (15 GB) erreicht **kein** lokales Modell ≥70 % A/B → `cpu-low.models` bleibt **leer** (immer substituieren). Gemessene Werte fließen in die `cpu-32`/`gpu-*`-Klassen, sobald solche HW real verfügbar ist; die hier gemessenen RAM/Latenz-Zahlen dokumentiert `eval-measurement.md` als Referenz/Default-Basis.

- [ ] **Step 5: Commit**

Commit `feat(evals): peak-RAM/latenz-messung + eval-measurement-doku` (Bulletpoints: run-evals.ps1 misst peak-RAM+geladene größe, 1 realer messlauf, eval-measurement.md mit methodik+werten, ramBuffer-default hergeleitet) + `Ref #268`.

---

## Task 10: End-User-Dokumentation

**Files:**
- Modify: `k.switchboard.net/docs/configuration.md`
- Modify: `k.switchboard.net/docs/troubleshooting.md`
- Create: `k.switchboard.net/docs/resource-aware-routing.md`

- [ ] **Step 1: configuration.md — neue Sektionen**

Ergänze (bestehenden Stil/Struktur von `configuration.md` folgen): HW-Profil-Cache (`hw-profile.json`, Ort, Refresh 1×/Monat, nicht committen), `HardwareClasses` (Schema + Beispiel-Klassen + VRAM-Schwellen 6144/10240/16384), `LocalModelTiers` + `TierSubstitutions` (mit Daten-Begründung: Tier-getrieben, L→Sonnet-Default/Opus-Opt-in, Verweis auf `eval-measurement.md`), `ResourceGate` (enabled, ramBufferMb, cpuLoadWindowSeconds, cpuMaxLoadPercent), Blast-Radius-Caps (num_thread, Serialisierung), Header `X-K-Switchboard-Substitution`.

- [ ] **Step 2: troubleshooting.md — neue Routing-Gründe**

Ergänze Einträge: „Request wird unerwartet auf Claude substituiert" (→ Gate-Log lesen: RAM/CPU/kein-Footprint; `X-K-Switchboard-Substitution`-Header erklärt den Grund), „HTTP 503 Local model not viable" (kein Fallback + kein Substitut konfiguriert), „GPU wird nicht erkannt" (nvidia-smi nicht im PATH → CPU-Pfad), „Profil veraltet" (Cache-Refresh 1×/Monat; manuell: `hw-profile.json` löschen).

- [ ] **Step 3: resource-aware-routing.md — Konzeptübersicht**

Create `k.switchboard.net/docs/resource-aware-routing.md`: Konzept (proaktiver Gate vs. reaktiver Fallback), Datenfluss-Diagramm (aus Spec §2), die zwei Datenspeicher (Per-Install-Profil a vs. committed Mapping b), Substitutions-Logik (Tier-basiert), Maschinenschutz (Blast-Radius), Transparenz (Log + Header). Verweise auf `configuration.md` + `eval-measurement.md`.

- [ ] **Step 4: Commit**

Commit `docs(switchboard): ressourcen-bewusstes routing dokumentiert` (Bulletpoints: configuration.md sektionen, troubleshooting routing-gründe, resource-aware-routing.md konzept) + `Ref #268`.

---

## Self-Review (durchgeführt beim Schreiben)

**Spec-Coverage (§-für-§):**
- §3.1 Detektor → Task 2 ✓ · §3.2 Cache/Refresh → Task 3 ✓ · §3.3 Live-Probe → Task 5 ✓ · §3.4 Classifier → Task 4 ✓ · §3.5 Gate → Task 6 ✓ · §3.6 Blast-Radius → Task 7 ✓ · §3.7 RoutingDecision → Task 6 ✓
- §4 Config (Records + Taxonomie + Tier-Substitution) → Task 1 (Records) + Task 8 Step 3 (Default-Werte) ✓
- §5 Admission/ramBuffer-Kalibrierung → Task 6 (Buffer-Default) + Task 9 Step 3 (Herleitung) ✓
- §6 Eval-Measurement → Task 9 ✓ · §7 Kein-Fallback→503 → Task 6 (Fail) + Task 8 (Endpoint) ✓
- §8 Docs → Task 10 ✓ · §9 Tests → in jeder Task (TUnit) ✓
- §10 MVP-Kriterien: alle abgedeckt. (+1/+2 bewusst NICHT in diesem Plan — Folge-Pläne.)

**Type-Konsistenz:** `RoutingAction{Proceed,Fail}`, `RoutingDecision{Action,EffectiveModel,Reason,SubstitutionHeader,FailStatusCode}`, `HardwareProfile{TotalRamMb,Cores,GpuVendor,GpuModel,VramMb,DetectedOn}`, `LiveResourceSnapshot{FreeRamMb,CpuLoadPercent,ModelWarm}`, `ModelValidation{PeakRamMb,ValidatedOn,LatencyP50Ms,Score}` — über alle Tasks konsistent verwendet. `ResourceGate.EvaluateAsync`, `HardwareProfileCache.GetAsync`, `ILiveResourceProbe.SampleAsync`, `IHardwareProfileDetector.DetectAsync`, `HardwareClassifier.Match` — Signaturen task-übergreifend stabil.

**Offene Punkte (bewusst, im Plan markiert):** wmic-VRAM >4GB-Überlauf (nur Fallback-Pfad; +1), CPU-Sampler nicht-Linux = 0 (+1), Defer-to-Fallback nutzt nur erstes Chain-Glied (+1), Integrationstest ggf. reduzierbar (Task 8 Step 5).

---

## Execution Handoff

**Plan vollständig und gespeichert unter `docs/superpowers/plans/2026-06-07-resource-aware-routing-mvp.md`.**

Gemäß globaler Einstellung (CLAUDE.md: Plan-Ausführung immer **subagent-driven**) wird dieser Plan via `superpowers:subagent-driven-development` umgesetzt — frischer Subagent pro Task, Zwei-Stufen-Review zwischen den Tasks. **ReleaseFlow:** Commits auf `feature/268-resource-aware-routing`, kein Push ohne expliziten Auftrag, Train-Check vor jedem Push.

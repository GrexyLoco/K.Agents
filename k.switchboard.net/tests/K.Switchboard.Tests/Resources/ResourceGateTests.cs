namespace K.Switchboard.Tests.Resources;

using K.Switchboard.Resources;

public sealed class ResourceGateTests
{
    private sealed class FakeProbe(LiveResourceSnapshot snap) : ILiveResourceProbe
    {
        public Task<LiveResourceSnapshot> SampleAsync(string model, int cpuWindowSeconds, CancellationToken ct)
            => Task.FromResult(snap);
    }

    private sealed class ThrowingProbe : ILiveResourceProbe
    {
        public Task<LiveResourceSnapshot> SampleAsync(string model, int cpuWindowSeconds, CancellationToken ct)
            => throw new InvalidOperationException("Monitor kaputt");
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
        var d = await gate.EvaluateAsync("local-coder", 0, CancellationToken.None);
        await Assert.That(d.Action).IsEqualTo(RoutingAction.Proceed);
        await Assert.That(d.EffectiveModel).IsEqualTo("local-coder");
        await Assert.That(d.SubstitutionHeader).IsNull();
    }

    [Test]
    public async Task Substitutes_to_claude_when_ram_too_low()
    {
        var gate = Build(new LiveResourceSnapshot { FreeRamMb = 2000, CpuLoadPercent = 10 }, Gpu14b);
        var d = await gate.EvaluateAsync("local-coder", 0, CancellationToken.None);
        await Assert.That(d.Action).IsEqualTo(RoutingAction.Proceed);
        await Assert.That(d.EffectiveModel).IsEqualTo("claude-sonnet-4-6");
        await Assert.That(d.SubstitutionHeader).IsNotNull();
    }

    [Test]
    public async Task Substitutes_when_cpu_overloaded()
    {
        var gate = Build(new LiveResourceSnapshot { FreeRamMb = 20000, CpuLoadPercent = 95 }, Gpu14b);
        var d = await gate.EvaluateAsync("local-coder", 0, CancellationToken.None);
        await Assert.That(d.EffectiveModel).IsEqualTo("claude-sonnet-4-6");
    }

    [Test]
    public async Task Defers_to_explicit_fallback_chain_before_substitution()
    {
        var gate = Build(
            new LiveResourceSnapshot { FreeRamMb = 2000, CpuLoadPercent = 10 }, Gpu14b,
            fallbacks: new() { ["local-coder"] = ["claude-opus-4-8"] });
        var d = await gate.EvaluateAsync("local-coder", 0, CancellationToken.None);
        await Assert.That(d.EffectiveModel).IsEqualTo("claude-opus-4-8");
        await Assert.That(d.SubstitutionHeader).IsNotNull();
    }

    [Test]
    public async Task Fails_5xx_when_no_substitute_and_no_fallback()
    {
        var opts = new SwitchboardOptions
        {
            ResourceGate = new ResourceGateOptions { Enabled = true },
            ModelAliases = new() { ["local-coder"] = "qwen2.5-coder:14b" },
            HardwareClasses = []
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
        var d = await gate.EvaluateAsync("local-coder", 0, CancellationToken.None);
        await Assert.That(d.Action).IsEqualTo(RoutingAction.Fail);
        await Assert.That(d.FailStatusCode).IsGreaterThanOrEqualTo(500);
    }

    [Test]
    public async Task Proceeds_unchanged_when_gate_disabled()
    {
        var gate = Build(new LiveResourceSnapshot { FreeRamMb = 100, CpuLoadPercent = 99 }, Gpu14b, enabled: false);
        var d = await gate.EvaluateAsync("local-coder", 0, CancellationToken.None);
        await Assert.That(d.Action).IsEqualTo(RoutingAction.Proceed);
        await Assert.That(d.EffectiveModel).IsEqualTo("local-coder");
    }

    [Test]
    public async Task Fails_open_to_proceed_when_resource_monitor_throws()
    {
        // Validiertes Modell (Pfad führt zur Probe), aber die Probe wirft → fail-open statt 500.
        var opts = new SwitchboardOptions
        {
            ResourceGate = new ResourceGateOptions { Enabled = true, CpuMaxLoadPercent = 85 },
            ModelAliases = new() { ["local-coder"] = "qwen2.5-coder:14b" },
            LocalModelTiers = new() { ["qwen2.5-coder:14b"] = "L" },
            TierSubstitutions = new() { ["L"] = "claude-sonnet-4-6" },
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
        var tmp = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
        Directory.CreateDirectory(tmp);
        var cache = new HardwareProfileCache(new FixedDetector(Gpu14b), tmp,
            Microsoft.Extensions.Logging.Abstractions.NullLogger<HardwareProfileCache>.Instance);
        var gate = new ResourceGate(new ModelRouter(optsMon), cache, new HardwareClassifier(),
            new ThrowingProbe(), optsMon,
            Microsoft.Extensions.Logging.Abstractions.NullLogger<ResourceGate>.Instance);

        var d = await gate.EvaluateAsync("local-coder", 0, CancellationToken.None);

        await Assert.That(d.Action).IsEqualTo(RoutingAction.Proceed);   // fail-open, kein 500
        await Assert.That(d.EffectiveModel).IsEqualTo("local-coder");   // unverändert durchgereicht
    }

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
        var gate = BuildGpu(new LiveResourceSnapshot { FreeRamMb = 1000, CpuLoadPercent = 10 }, NvidiaGpu16gb, peakVramMb: 9000);
        var d = await gate.EvaluateAsync("local-coder", 0, CancellationToken.None);
        await Assert.That(d.Action).IsEqualTo(RoutingAction.Proceed);
        await Assert.That(d.EffectiveModel).IsEqualTo("local-coder");
    }

    [Test]
    public async Task Gpu_substitutes_when_vram_below_reserve_adjusted_need()
    {
        var gate = BuildGpu(new LiveResourceSnapshot { FreeRamMb = 30000, CpuLoadPercent = 10 }, NvidiaGpu16gb, peakVramMb: 15000);
        var d = await gate.EvaluateAsync("local-coder", 0, CancellationToken.None);
        await Assert.That(d.EffectiveModel).IsEqualTo("claude-sonnet-4-6");
    }

    [Test]
    public async Task Cpu_path_used_when_model_has_no_peak_vram()
    {
        var gate = BuildGpu(new LiveResourceSnapshot { FreeRamMb = 1000, CpuLoadPercent = 10 }, NvidiaGpu16gb, peakVramMb: 0);
        var d = await gate.EvaluateAsync("local-coder", 0, CancellationToken.None);
        // PeakRamMb=2000, buffer=max(1024,500)=1024, need=3024; FreeRam=1000 < 3024 → Substitution.
        await Assert.That(d.EffectiveModel).IsEqualTo("claude-sonnet-4-6");
    }
}

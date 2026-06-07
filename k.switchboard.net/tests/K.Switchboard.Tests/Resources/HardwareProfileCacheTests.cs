namespace K.Switchboard.Tests.Resources;

using System.Text.Json;
using System.Text.Json.Serialization;
using K.Switchboard.Resources;

// Test-lokaler source-gen-context (test-projekt hat JsonSerializerIsReflectionEnabledByDefault=false).
[JsonSerializable(typeof(HardwareProfile))]
internal sealed partial class HwProfileTestJsonContext : JsonSerializerContext;

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
        var stale = new HardwareProfile { TotalRamMb = 16000, Cores = 4, DetectedOn = DateTimeOffset.UtcNow.AddDays(-40) };
        await File.WriteAllTextAsync(Path.Combine(dir, "hw-profile.json"),
            JsonSerializer.Serialize(stale, HwProfileTestJsonContext.Default.HardwareProfile));
        var detector = new CountingDetector(new HardwareProfile { TotalRamMb = 32000, Cores = 8 });
        var cache = new HardwareProfileCache(detector, dir,
            Microsoft.Extensions.Logging.Abstractions.NullLogger<HardwareProfileCache>.Instance);

        var p = await cache.GetAsync(CancellationToken.None);

        await Assert.That(detector.Calls).IsEqualTo(1);
        await Assert.That(p.TotalRamMb).IsEqualTo(32000);   // frisch erkannt, nicht der stale-Wert
    }
}

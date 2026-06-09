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

    // Reale 5-Klassen-Taxonomie (Reihenfolge = Match-Priorität, cpu-32 = Catch-all OHNE gpuVendor).
    private static List<HardwareClassConfig> RealTaxonomy() =>
    [
        new() { Name = "cpu-low",      Match = new() { MaxRamMb = 16384 } },
        new() { Name = "gpu-7b",       Match = new() { MinVramMb = 6144,  MaxVramMb = 10239 } },
        new() { Name = "gpu-14b",      Match = new() { MinVramMb = 10240, MaxVramMb = 16383 } },
        new() { Name = "gpu-14b-plus", Match = new() { MinVramMb = 16384 } },
        new() { Name = "cpu-32",       Match = new() { MinRamMb = 24576 } },
    ];

    [Test]
    [Arguments(15400, "none", 0, "cpu-low")]      // Laptop
    [Arguments(32000, "NVIDIA", 3584, "cpu-32")]  // GTX 970 (3,5GB) → zu wenig VRAM → Catch-all
    [Arguments(32000, "AMD", 0, "cpu-32")]        // AMD ohne VRAM-Read → Catch-all (KEIN gpuVendor-Constraint!)
    [Arguments(32000, "NVIDIA", 11264, "gpu-14b")]      // GTX 1080 Ti
    [Arguments(32000, "NVIDIA", 16384, "gpu-14b-plus")] // RTX 5070 Ti
    public async Task Real_taxonomy_routes_machines_to_expected_class(int ramMb, string vendor, int vramMb, string expected)
    {
        var classifier = new HardwareClassifier();
        var profile = new HardwareProfile { TotalRamMb = ramMb, Cores = 8, GpuVendor = vendor, VramMb = vramMb };

        var match = classifier.Match(profile, RealTaxonomy());

        await Assert.That(match?.Name).IsEqualTo(expected);
    }
}

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

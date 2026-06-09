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

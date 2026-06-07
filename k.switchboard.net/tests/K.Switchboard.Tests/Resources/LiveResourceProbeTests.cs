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

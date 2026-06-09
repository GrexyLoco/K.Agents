namespace K.Switchboard.Tests.Resources;

using K.Switchboard.Resources;

public sealed class CpuLoadSamplerTests
{
    [Test]
    [Arguments(1000L, 250L, 75.0)]
    [Arguments(1000L, 1000L, 0.0)]
    [Arguments(0L, 0L, 0.0)]
    [Arguments(1000L, 0L, 100.0)]
    public async Task BusyPercent_computes_correctly(long totalDelta, long idleDelta, double expected)
    {
        await Assert.That(CpuLoadSampler.BusyPercent(totalDelta, idleDelta)).IsEqualTo(expected);
    }

    [Test]
    public async Task SampleAsync_returns_value_in_valid_range()
    {
        var sampler = new CpuLoadSampler();
        var load = await sampler.SampleAsync(1, CancellationToken.None);

        await Assert.That(load).IsGreaterThanOrEqualTo(0.0);
        await Assert.That(load).IsLessThanOrEqualTo(100.0);
    }
}

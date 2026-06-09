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

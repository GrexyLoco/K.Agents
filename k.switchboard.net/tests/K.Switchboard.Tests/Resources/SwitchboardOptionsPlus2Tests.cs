namespace K.Switchboard.Tests.Resources;

public sealed class SwitchboardOptionsPlus2Tests
{
    [Test]
    public async Task CreateDefault_has_plus2_flags_off()
    {
        var opts = SwitchboardOptions.CreateDefault();
        await Assert.That(opts.ResourceGate.LowerOllamaPriority).IsFalse();
        await Assert.That(opts.ResourceGate.RecordLocalInferenceStats).IsFalse();
    }
}

namespace K.Switchboard.Tests.Resources;

using K.Switchboard.Resources;

public sealed class ProcessControllerTests
{
    [Test]
    public async Task FindByName_returns_empty_for_unknown_process()
    {
        var ctrl = new ProcessController();
        var pids = ctrl.FindByName("definitely-not-a-real-process-xyz123");
        await Assert.That(pids).IsEmpty();
    }

    [Test]
    public async Task TrySetBelowNormal_returns_false_for_invalid_pid()
    {
        var ctrl = new ProcessController();
        var ok = ctrl.TrySetBelowNormal(-1);
        await Assert.That(ok).IsFalse();
    }
}

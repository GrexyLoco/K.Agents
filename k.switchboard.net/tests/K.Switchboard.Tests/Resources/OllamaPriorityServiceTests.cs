namespace K.Switchboard.Tests.Resources;

using K.Switchboard.Resources;

public sealed class OllamaPriorityServiceTests
{
    private sealed class FakeProcessController : IProcessController
    {
        public List<int> LoweredPids { get; } = [];
        public int[] Found { get; init; } = [];
        public IReadOnlyList<int> FindByName(string processName) => Found;
        public bool TrySetBelowNormal(int pid) { LoweredPids.Add(pid); return true; }
    }

    private static OllamaPriorityService Build(FakeProcessController ctrl, bool enabled, string ollamaUrl)
    {
        var opts = new SwitchboardOptions
        {
            OllamaBaseUrl = ollamaUrl,
            ResourceGate = new ResourceGateOptions { LowerOllamaPriority = enabled }
        };
        return new OllamaPriorityService(ctrl, new FakeOptionsMonitor<SwitchboardOptions>(opts),
            Microsoft.Extensions.Logging.Abstractions.NullLogger<OllamaPriorityService>.Instance);
    }

    [Test]
    public async Task Lowers_local_ollama_when_enabled()
    {
        var ctrl = new FakeProcessController { Found = [111, 222] };
        var svc = Build(ctrl, enabled: true, ollamaUrl: "http://localhost:11434");
        svc.ApplyOnce();
        await Assert.That(ctrl.LoweredPids).Contains(111);
        await Assert.That(ctrl.LoweredPids).Contains(222);
    }

    [Test]
    public async Task Skips_when_disabled()
    {
        var ctrl = new FakeProcessController { Found = [111] };
        var svc = Build(ctrl, enabled: false, ollamaUrl: "http://localhost:11434");
        svc.ApplyOnce();
        await Assert.That(ctrl.LoweredPids).IsEmpty();
    }

    [Test]
    public async Task Skips_when_ollama_remote()
    {
        var ctrl = new FakeProcessController { Found = [111] };
        var svc = Build(ctrl, enabled: true, ollamaUrl: "http://gpu-box.intern:11434");
        svc.ApplyOnce();
        await Assert.That(ctrl.LoweredPids).IsEmpty();
    }
}

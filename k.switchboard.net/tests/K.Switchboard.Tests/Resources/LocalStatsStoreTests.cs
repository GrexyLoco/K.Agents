namespace K.Switchboard.Tests.Resources;

using K.Switchboard.Resources;

public sealed class LocalStatsStoreTests
{
    private static string FreshDir()
    {
        var d = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
        Directory.CreateDirectory(d);
        return d;
    }

    [Test]
    public async Task Record_aggregates_count_avg_max()
    {
        var dir = FreshDir();
        var store = new LocalStatsStore(dir,
            Microsoft.Extensions.Logging.Abstractions.NullLogger<LocalStatsStore>.Instance);

        store.Record("qwen2.5-coder:14b", elapsedMs: 100, ramDeltaMb: 9000, sizeMb: 9000);
        store.Record("qwen2.5-coder:14b", elapsedMs: 300, ramDeltaMb: 9100, sizeMb: 9000);

        var s = store.Get("qwen2.5-coder:14b")!;
        await Assert.That(s.Count).IsEqualTo(2);
        await Assert.That(s.MaxLatencyMs).IsEqualTo(300);
        await Assert.That(s.LastLatencyMs).IsEqualTo(300);
        await Assert.That(s.AvgLatencyMs).IsEqualTo(200.0);
    }

    [Test]
    public async Task Persists_across_instances()
    {
        var dir = FreshDir();
        var store1 = new LocalStatsStore(dir,
            Microsoft.Extensions.Logging.Abstractions.NullLogger<LocalStatsStore>.Instance);
        store1.Record("llama3.2:3b", elapsedMs: 50, ramDeltaMb: 4000, sizeMb: 3900);

        var store2 = new LocalStatsStore(dir,
            Microsoft.Extensions.Logging.Abstractions.NullLogger<LocalStatsStore>.Instance);
        var s = store2.Get("llama3.2:3b")!;
        await Assert.That(s.Count).IsEqualTo(1);
        await Assert.That(s.LastSizeMb).IsEqualTo(3900);
    }
}

namespace K.Switchboard.Tests.Resources;

using System.Text.Json.Nodes;
using K.Switchboard.Providers;

public sealed class OllamaBlastRadiusTests
{
    [Test]
    public async Task Sets_num_thread_in_options()
    {
        using var bodyStream = new MemoryStream(
            System.Text.Encoding.UTF8.GetBytes("""{"model":"x","messages":[],"max_tokens":256}"""));

        var (body, _) = await OllamaProvider.BuildOllamaBodyForTest(bodyStream, "qwen2.5-coder:14b", "30m", numThread: 6, CancellationToken.None);

        var options = body["options"] as JsonObject;
        await Assert.That(options).IsNotNull();
        await Assert.That(options!["num_thread"]!.GetValue<int>()).IsEqualTo(6);
        await Assert.That(options["num_predict"]!.GetValue<int>()).IsEqualTo(256);
    }

    [Test]
    public async Task Num_thread_present_even_without_max_tokens()
    {
        using var bodyStream = new MemoryStream(
            System.Text.Encoding.UTF8.GetBytes("""{"model":"x","messages":[]}"""));

        var (body, _) = await OllamaProvider.BuildOllamaBodyForTest(bodyStream, "m", "30m", numThread: 4, CancellationToken.None);

        var options = body["options"] as JsonObject;
        await Assert.That(options!["num_thread"]!.GetValue<int>()).IsEqualTo(4);
    }
}

namespace K.Switchboard.Tests;

using System.Text.Json;

public sealed class RequestTokenEstimatorTests
{
    [Test]
    public async Task Estimates_from_string_and_block_content()
    {
        using var doc = JsonDocument.Parse("""
        {"model":"x","messages":[
          {"role":"user","content":"aaaaaaaa"},
          {"role":"assistant","content":[{"type":"text","text":"bbbbbbbb"}]}
        ]}
        """);
        // 8 + 8 = 16 Zeichen / 4 = 4 Tokens.
        var tokens = RequestTokenEstimator.EstimateInputTokens(doc.RootElement);
        await Assert.That(tokens).IsEqualTo(4);
    }

    [Test]
    public async Task Returns_zero_without_messages()
    {
        using var doc = JsonDocument.Parse("""{"model":"x"}""");
        await Assert.That(RequestTokenEstimator.EstimateInputTokens(doc.RootElement)).IsEqualTo(0);
    }
}

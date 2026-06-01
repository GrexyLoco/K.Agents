namespace K.Switchboard.Tests.Services;

/// <summary>Unit-Tests für <see cref="CostingService"/>.</summary>
public sealed class CostingServiceTests
{
    // --- Token-Extraktion ---

    [Test]
    public async Task TryExtractUsage_ValidAnthropicResponse_ReturnsTokens()
    {
        var body = Encoding.UTF8.GetBytes("""
            {"id":"msg_1","type":"message","usage":{"input_tokens":150,"output_tokens":300}}
            """);

        var extracted = CostingService.TryExtractUsage(body, out var input, out var output);

        await Assert.That(extracted).IsTrue();
        await Assert.That(input).IsEqualTo(150);
        await Assert.That(output).IsEqualTo(300);
    }

    [Test]
    public async Task TryExtractUsage_NoUsageField_ReturnsFalse()
    {
        var body = Encoding.UTF8.GetBytes("""{"id":"msg_1","type":"message"}""");

        var extracted = CostingService.TryExtractUsage(body, out _, out _);

        await Assert.That(extracted).IsFalse();
    }

    [Test]
    public async Task TryExtractUsage_EmptyBody_ReturnsFalse()
    {
        var extracted = CostingService.TryExtractUsage([], out _, out _);

        await Assert.That(extracted).IsFalse();
    }

    [Test]
    public async Task TryExtractUsage_InvalidJson_ReturnsFalse()
    {
        var body = Encoding.UTF8.GetBytes("not-json");

        var extracted = CostingService.TryExtractUsage(body, out _, out _);

        await Assert.That(extracted).IsFalse();
    }

    // --- SSE-Streaming-Extraktion (Issue #250) ---

    [Test]
    public async Task TryExtractUsage_AnthropicSseStream_TakesInputFromStartAndCumulativeOutput()
    {
        // Anthropic-SSE: message_start trägt input_tokens=25/output_tokens=1,
        // message_delta liefert KUMULATIVE output_tokens (10, dann 15).
        // Erwartung: input=25, output=15 (nicht 1+10+15).
        var body = Encoding.UTF8.GetBytes(
            "event: message_start\n" +
            "data: {\"type\":\"message_start\",\"message\":{\"id\":\"msg_1\",\"usage\":{\"input_tokens\":25,\"output_tokens\":1}}}\n\n" +
            "event: message_delta\n" +
            "data: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":null},\"usage\":{\"output_tokens\":10}}\n\n" +
            "event: message_delta\n" +
            "data: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"end_turn\"},\"usage\":{\"output_tokens\":15}}\n\n" +
            "event: message_stop\n" +
            "data: {\"type\":\"message_stop\"}\n\n");

        var extracted = CostingService.TryExtractUsage(body, out var input, out var output);

        await Assert.That(extracted).IsTrue();
        await Assert.That(input).IsEqualTo(25);
        await Assert.That(output).IsEqualTo(15);
    }

    [Test]
    public async Task TryExtractUsage_OllamaEmittedSseStream_ReadsFinalDeltaUsage()
    {
        // Ollama-emittierte SSE-Form: message_start mit usage 0/0 (unter message),
        // finales message_delta mit Top-Level usage (input=prompt_eval, output=eval).
        var body = Encoding.UTF8.GetBytes(
            "data: {\"type\":\"message_start\",\"message\":{\"id\":\"msg_ollama\",\"usage\":{\"input_tokens\":0,\"output_tokens\":0}}}\n\n" +
            "data: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"hi\"}}\n\n" +
            "data: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"end_turn\"},\"usage\":{\"input_tokens\":42,\"output_tokens\":17}}\n\n" +
            "data: [DONE]\n\n");

        var extracted = CostingService.TryExtractUsage(body, out var input, out var output);

        await Assert.That(extracted).IsTrue();
        await Assert.That(input).IsEqualTo(42);
        await Assert.That(output).IsEqualTo(17);
    }

    [Test]
    public async Task TryExtractUsage_SseWithDoneSentinelAndGarbageLines_IgnoredRobustly()
    {
        var body = Encoding.UTF8.GetBytes(
            ": this is an SSE comment\n" +
            "event: message_start\n" +
            "data: {\"type\":\"message_start\",\"message\":{\"usage\":{\"input_tokens\":7,\"output_tokens\":2}}}\n\n" +
            "data: not-json-at-all\n\n" +
            "data: [DONE]\n\n");

        var extracted = CostingService.TryExtractUsage(body, out var input, out var output);

        await Assert.That(extracted).IsTrue();
        await Assert.That(input).IsEqualTo(7);
        await Assert.That(output).IsEqualTo(2);
    }

    [Test]
    public async Task TryExtractUsage_DecimalTokenValue_SkipsFieldWithoutThrowing()
    {
        // Robustheit (Try-Vertrag): ein dezimaler output_tokens-Wert (25.5) darf NICHT werfen.
        // Erwartung: Dezimalfeld wird übersprungen, geschwisterliches input_tokens=150 bleibt lesbar.
        var body = Encoding.UTF8.GetBytes("""
            {"usage":{"input_tokens":150,"output_tokens":25.5}}
            """);

        var extracted = CostingService.TryExtractUsage(body, out var input, out var output);

        await Assert.That(extracted).IsTrue();
        await Assert.That(input).IsEqualTo(150);
        await Assert.That(output).IsEqualTo(0);
    }

    [Test]
    public async Task TryExtractUsage_StringTokenValue_SkipsFieldWithoutThrowing()
    {
        // Try-Vertrag: ein nicht-numerischer (String-)Token-Wert darf NICHT werfen.
        // ValueKind-Guard verhindert den InvalidOperationException-Pfad von TryGetInt32.
        var body = Encoding.UTF8.GetBytes("""
            {"usage":{"input_tokens":150,"output_tokens":"abc"}}
            """);

        var extracted = CostingService.TryExtractUsage(body, out var input, out var output);

        await Assert.That(extracted).IsTrue();
        await Assert.That(input).IsEqualTo(150);
        await Assert.That(output).IsEqualTo(0);
    }

    [Test]
    public async Task TryExtractUsage_AnthropicSseStreamWithCrlf_TakesInputFromStartAndCumulativeOutput()
    {
        // Wie der Anthropic-SSE-Test, aber mit CRLF-Zeilenenden (\r\n) statt \n.
        // TrimEnd('\r') muss die data:-Zeilen identisch parsen.
        var body = Encoding.UTF8.GetBytes(
            "event: message_start\r\n" +
            "data: {\"type\":\"message_start\",\"message\":{\"id\":\"msg_1\",\"usage\":{\"input_tokens\":25,\"output_tokens\":1}}}\r\n\r\n" +
            "event: message_delta\r\n" +
            "data: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":null},\"usage\":{\"output_tokens\":10}}\r\n\r\n" +
            "event: message_delta\r\n" +
            "data: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"end_turn\"},\"usage\":{\"output_tokens\":15}}\r\n\r\n" +
            "event: message_stop\r\n" +
            "data: {\"type\":\"message_stop\"}\r\n\r\n");

        var extracted = CostingService.TryExtractUsage(body, out var input, out var output);

        await Assert.That(extracted).IsTrue();
        await Assert.That(input).IsEqualTo(25);
        await Assert.That(output).IsEqualTo(15);
    }

    [Test]
    public async Task TryExtractUsage_EmptySseWithoutUsage_ReturnsFalse()
    {
        var body = Encoding.UTF8.GetBytes(
            "event: ping\n" +
            "data: {\"type\":\"ping\"}\n\n" +
            "data: [DONE]\n\n");

        var extracted = CostingService.TryExtractUsage(body, out var input, out var output);

        await Assert.That(extracted).IsFalse();
        await Assert.That(input).IsEqualTo(0);
        await Assert.That(output).IsEqualTo(0);
    }

    [Test]
    public async Task RecordUsageAsync_AnthropicSse_ThenGetStats_AggregatesTokens()
    {
        var opts = new SwitchboardOptions
        {
            Pricing = new Dictionary<string, ModelPricing>
            {
                ["claude-3-5-sonnet"] = new ModelPricing
                {
                    InputPerMillion = 3m,
                    OutputPerMillion = 15m
                }
            }
        };
        var svc = CreateService(opts);

        var body = Encoding.UTF8.GetBytes(
            "event: message_start\n" +
            "data: {\"type\":\"message_start\",\"message\":{\"usage\":{\"input_tokens\":25,\"output_tokens\":1}}}\n\n" +
            "event: message_delta\n" +
            "data: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"end_turn\"},\"usage\":{\"output_tokens\":15}}\n\n");

        await svc.RecordUsageAsync("claude-3-5-sonnet", body);

        var stats = svc.GetDailyStats();

        await Assert.That(stats.Models.ContainsKey("claude-3-5-sonnet")).IsTrue();
        await Assert.That(stats.Models["claude-3-5-sonnet"].InputTokens).IsEqualTo(25);
        await Assert.That(stats.Models["claude-3-5-sonnet"].OutputTokens).IsEqualTo(15);
    }

    [Test]
    public async Task RecordUsageAsync_ClaudeModelWithoutPricing_StillRecordsEntryWithZeroCost()
    {
        // Akzeptanzkriterium: fehlendes Pricing → Eintrag wird TROTZDEM angelegt (CostUsd=0),
        // nicht übersprungen.
        var svc = CreateService(new SwitchboardOptions());

        var body = Encoding.UTF8.GetBytes(
            "event: message_start\n" +
            "data: {\"type\":\"message_start\",\"message\":{\"usage\":{\"input_tokens\":25,\"output_tokens\":1}}}\n\n" +
            "event: message_delta\n" +
            "data: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"end_turn\"},\"usage\":{\"output_tokens\":15}}\n\n");

        await svc.RecordUsageAsync("claude-3-opus-unpriced", body);

        var stats = svc.GetDailyStats();

        await Assert.That(stats.Models.ContainsKey("claude-3-opus-unpriced")).IsTrue();
        await Assert.That(stats.Models["claude-3-opus-unpriced"].InputTokens).IsEqualTo(25);
        await Assert.That(stats.Models["claude-3-opus-unpriced"].OutputTokens).IsEqualTo(15);
        await Assert.That(stats.Models["claude-3-opus-unpriced"].CostUsd).IsEqualTo(0m);
    }

    // --- Kostenberechnung ---

    [Test]
    public async Task CalculateCost_WithPricing_ReturnsCorrectCost()
    {
        var opts = new SwitchboardOptions
        {
            Pricing = new Dictionary<string, ModelPricing>
            {
                ["claude-3-opus"] = new ModelPricing
                {
                    InputPerMillion = 15m,
                    OutputPerMillion = 75m
                }
            }
        };
        var svc = CreateService(opts);

        // 1000 input @ $15/M = $0.015, 500 output @ $75/M = $0.0375 → $0.0525
        var cost = svc.CalculateCost("claude-3-opus", 1000, 500);

        await Assert.That(cost).IsEqualTo(0.0525m);
    }

    [Test]
    public async Task CalculateCost_UnknownModel_ReturnsZero()
    {
        var svc = CreateService(new SwitchboardOptions());

        var cost = svc.CalculateCost("unknown-model", 1000, 500);

        await Assert.That(cost).IsEqualTo(0m);
    }

    // --- RecordUsage + GetDailyStats (Roundtrip) ---

    [Test]
    public async Task RecordUsageAsync_ThenGetStats_ReturnsAccumulatedData()
    {
        var opts = new SwitchboardOptions
        {
            Pricing = new Dictionary<string, ModelPricing>
            {
                ["claude-3-haiku"] = new ModelPricing
                {
                    InputPerMillion = 0.25m,
                    OutputPerMillion = 1.25m
                }
            }
        };
        var svc = CreateService(opts);

        var response = Encoding.UTF8.GetBytes("""
            {"usage":{"input_tokens":500,"output_tokens":200}}
            """);

        await svc.RecordUsageAsync("claude-3-haiku", response);

        var stats = svc.GetDailyStats();

        await Assert.That(stats.Models.ContainsKey("claude-3-haiku")).IsTrue();
        await Assert.That(stats.Models["claude-3-haiku"].InputTokens).IsEqualTo(500);
        await Assert.That(stats.Models["claude-3-haiku"].OutputTokens).IsEqualTo(200);
        await Assert.That(stats.TotalCostUsd).IsGreaterThan(0m);
    }

    [Test]
    public async Task GetDailyStats_NoData_ReturnsEmptyStats()
    {
        var svc = CreateService(new SwitchboardOptions());

        var stats = svc.GetDailyStats();

        await Assert.That(stats.Models).IsEmpty();
        await Assert.That(stats.TotalCostUsd).IsEqualTo(0m);
    }

    // --- Hilfsmethoden ---

    private static CostingService CreateService(SwitchboardOptions opts)
    {
        var tmpDir = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
        Directory.CreateDirectory(tmpDir);
        return new CostingService(
            new FakeOptionsMonitor<SwitchboardOptions>(opts),
            Microsoft.Extensions.Logging.Abstractions.NullLogger<CostingService>.Instance,
            tmpDir);
    }
}

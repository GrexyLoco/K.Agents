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

using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace K.Switchboard.Tests.Integration;

/// <summary>
/// Fixture, die die WebApplicationFactory kapselt und pro Test-Session genau einmal erstellt wird.
/// Isoliert CostingService in ein eigenes Temp-Verzeichnis (kein Seiteneffekt auf %APPDATA%).
/// </summary>
public sealed class SwitchboardTestFixture : IAsyncDisposable
{
    private readonly string _tempDir;
    private readonly WebApplicationFactory<Program> _factory;

    public HttpClient Client { get; }
    public IServiceProvider Services => _factory.Services;

    public SwitchboardTestFixture()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
        Directory.CreateDirectory(_tempDir);

        _factory = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                // CostingService mit isoliertem Temp-Verzeichnis neu registrieren
                // (verhindert Verschmutzung durch echte %APPDATA%\K.Switchboard\costs-*.json)
                services.RemoveAll<CostingService>();
                services.AddSingleton<CostingService>(sp =>
                    new CostingService(
                        sp.GetRequiredService<IOptionsMonitor<SwitchboardOptions>>(),
                        sp.GetRequiredService<Microsoft.Extensions.Logging.ILogger<CostingService>>(),
                        _tempDir));
            });
        });

        Client = _factory.CreateClient();
    }

    public async ValueTask DisposeAsync()
    {
        Client.Dispose();
        await _factory.DisposeAsync();
        if (Directory.Exists(_tempDir))
            Directory.Delete(_tempDir, recursive: true);
    }
}

/// <summary>
/// Integrationstests für GET /stats über die echte HTTP-Pipeline.
/// Reproduziert Bug #247: Trim-Serialisierung schlägt fehl, wenn kein Source-Gen-TypeInfoResolver
/// als globaler HttpJson-Resolver registriert ist (JsonSerializerIsReflectionEnabledByDefault=false).
/// </summary>
[NotInParallel("stats-integration")]
public sealed class StatsEndpointTests
{
    [Test]
    [ClassDataSource<SwitchboardTestFixture>(Shared = SharedType.PerTestSession)]
    public async Task GetStats_OhneErfassteRequests_Liefert200MitLeeremDailyStats(
        SwitchboardTestFixture fixture)
    {
        // Act
        var response = await fixture.Client.GetAsync("/stats");

        // Assert — 200, kein 500 durch fehlende TypeInfoResolver
        await Assert.That((int)response.StatusCode).IsEqualTo(200);

        var body = await response.Content.ReadAsStringAsync();
        await Assert.That(body).IsNotNull();
        await Assert.That(body).IsNotEmpty();

        // JSON muss wohlgeformt sein und die erwarteten Felder (camelCase) enthalten
        using var doc = JsonDocument.Parse(body);
        var root = doc.RootElement;

        await Assert.That(root.TryGetProperty("date", out _)).IsTrue();
        await Assert.That(root.TryGetProperty("models", out _)).IsTrue();
        await Assert.That(root.TryGetProperty("totalCostUsd", out _)).IsTrue();

        // Keine vorherigen Requests → leere Models-Map
        var models = root.GetProperty("models");
        await Assert.That(models.ValueKind).IsEqualTo(JsonValueKind.Object);
    }

    [Test]
    [ClassDataSource<SwitchboardTestFixture>(Shared = SharedType.PerTestSession)]
    public async Task GetStats_NachRecordUsage_Liefert200MitAggregiertenWerten(
        SwitchboardTestFixture fixture)
    {
        // Arrange — Nutzung über den isolierten CostingService eintragen
        var costing = fixture.Services.GetRequiredService<CostingService>();
        var responseBody = Encoding.UTF8.GetBytes(
            """{"usage":{"input_tokens":100,"output_tokens":50}}""");
        await costing.RecordUsageAsync("claude-stats-test", responseBody);

        // Act
        var response = await fixture.Client.GetAsync("/stats");

        // Assert
        await Assert.That((int)response.StatusCode).IsEqualTo(200);

        var body = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(body);
        var root = doc.RootElement;

        await Assert.That(root.TryGetProperty("models", out var modelsEl)).IsTrue();
        await Assert.That(modelsEl.TryGetProperty("claude-stats-test", out var modelEl)).IsTrue();
        await Assert.That(modelEl.GetProperty("inputTokens").GetInt32()).IsEqualTo(100);
        await Assert.That(modelEl.GetProperty("outputTokens").GetInt32()).IsEqualTo(50);
    }
}

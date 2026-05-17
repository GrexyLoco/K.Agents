namespace K.Switchboard.Tests.Services;

/// <summary>Unit-Tests für <see cref="FallbackService"/>.</summary>
public sealed class FallbackServiceTests
{
    // --- Primär erfolgreich ---

    [Test]
    public async Task Forward_PrimarySucceeds_NoFallbackHeader()
    {
        var (svc, _, ctx) = Build(primaryStatus: 200);

        await svc.ForwardWithFallbackAsync(ctx, "claude-3-opus", CancellationToken.None);

        await Assert.That(ctx.Response.StatusCode).IsEqualTo(200);
        await Assert.That(ctx.Response.Headers.ContainsKey("X-K-Switchboard-Fallback-Used")).IsFalse();
    }

    [Test]
    public async Task Forward_PrimarySucceeds_ResponseBodyForwarded()
    {
        const string body = """{"id":"msg_1","type":"message"}""";
        var (svc, _, ctx) = Build(primaryStatus: 200, primaryBody: body);

        await svc.ForwardWithFallbackAsync(ctx, "claude-3-opus", CancellationToken.None);

        ctx.Response.Body.Position = 0;
        var written = await new StreamReader(ctx.Response.Body).ReadToEndAsync();
        await Assert.That(written).IsEqualTo(body);
    }

    // --- Primär fehlschlägt, Fallback greift ---

    [Test]
    public async Task Forward_PrimaryFails_FallbackUsed_HeaderSet()
    {
        // "codellama:13b" enthält ':' → ModelRouter routet zu "ollama" (Status 200)
        var (svc, _, ctx) = Build(
            primaryStatus: 500,
            fallbackStatus: 200,
            primaryModel: "claude-3-opus",
            fallbacks: ["codellama:13b"]);

        await svc.ForwardWithFallbackAsync(ctx, "claude-3-opus", CancellationToken.None);

        await Assert.That(ctx.Response.StatusCode).IsEqualTo(200);
        await Assert.That(ctx.Response.Headers.ContainsKey("X-K-Switchboard-Fallback-Used")).IsTrue();
        var header = ctx.Response.Headers["X-K-Switchboard-Fallback-Used"].ToString();
        await Assert.That(header).Contains("claude-3-opus");
        await Assert.That(header).Contains("codellama:13b");
    }

    // --- Kein Fallback konfiguriert ---

    [Test]
    public async Task Forward_PrimaryFails_NoFallbackConfigured_ErrorResponseReturned()
    {
        var (svc, _, ctx) = Build(primaryStatus: 503, fallbacks: []);

        await svc.ForwardWithFallbackAsync(ctx, "claude-3-opus", CancellationToken.None);

        await Assert.That(ctx.Response.StatusCode).IsEqualTo(503);
        await Assert.That(ctx.Response.Headers.ContainsKey("X-K-Switchboard-Fallback-Used")).IsFalse();
    }

    [Test]
    public async Task Forward_PrimaryFails_FallbackThrows_NoFalse200Returned()
    {
        var (svc, _, ctx) = Build(
            primaryStatus: 500,
            primaryModel: "claude-3-opus",
            fallbacks: ["codellama:13b"],
            fallbackThrows: true);

        await svc.ForwardWithFallbackAsync(ctx, "claude-3-opus", CancellationToken.None);

        await Assert.That(ctx.Response.StatusCode).IsEqualTo(500);
        await Assert.That(ctx.Response.Headers.ContainsKey("X-K-Switchboard-Fallback-Used")).IsFalse();
    }

    [Test]
    public async Task Forward_PrimaryThrows_NoFallbackConfigured_ReturnsBadGateway()
    {
        var (svc, _, ctx) = Build(primaryThrows: true, fallbacks: []);

        await svc.ForwardWithFallbackAsync(ctx, "claude-3-opus", CancellationToken.None);

        await Assert.That(ctx.Response.StatusCode).IsEqualTo(502);
        await Assert.That(ctx.Response.Headers.ContainsKey("X-K-Switchboard-Fallback-Used")).IsFalse();
    }

    [Test]
    public async Task Forward_PrimaryJsonException_ReturnsBadRequest()
    {
        var (svc, _, ctx) = Build(primaryThrowsJson: true, fallbacks: ["codellama:13b"]);

        await svc.ForwardWithFallbackAsync(ctx, "claude-3-opus", CancellationToken.None);

        await Assert.That(ctx.Response.StatusCode).IsEqualTo(400);
        await Assert.That(ctx.Response.Headers.ContainsKey("X-K-Switchboard-Fallback-Used")).IsFalse();

        ctx.Response.Body.Position = 0;
        var body = await new StreamReader(ctx.Response.Body).ReadToEndAsync();
        await Assert.That(body).Contains("Invalid JSON payload");
    }

    [Test]
    public async Task Forward_PrimaryProviderMissing_ReturnsInternalServerError()
    {
        var (svc, _, ctx) = Build(includePrimaryProvider: false);

        await svc.ForwardWithFallbackAsync(ctx, "claude-3-opus", CancellationToken.None);

        await Assert.That(ctx.Response.StatusCode).IsEqualTo(500);
        ctx.Response.Body.Position = 0;
        var body = await new StreamReader(ctx.Response.Body).ReadToEndAsync();
        await Assert.That(body).Contains("Provider misconfiguration");
    }

    // --- Hilfsmethoden ---

    private static (FallbackService Service, CostingService Costing, DefaultHttpContext Context) Build(
        int primaryStatus = 200,
        string primaryBody = "{}",
        bool primaryThrows = false,
        bool primaryThrowsJson = false,
        bool includePrimaryProvider = true,
        int fallbackStatus = 200,
        string fallbackBody = "{}",
        bool fallbackThrows = false,
        string primaryModel = "claude-3-opus",
        List<string>? fallbacks = null)
    {
        fallbacks ??= [];

        var opts = new SwitchboardOptions
        {
            FallbackChains = fallbacks.Count > 0
                ? new Dictionary<string, List<string>> { [primaryModel] = fallbacks }
                : []
        };
        var optsMon = new FakeOptionsMonitor<SwitchboardOptions>(opts);

        // Stub-Provider: "anthropic" = primary, all fallback names also mapped
        var allProviders = new List<IProvider>();
        if (includePrimaryProvider)
        {
            allProviders.Add(primaryThrows
                ? new ThrowingProvider("anthropic")
                : primaryThrowsJson
                    ? new ThrowingJsonProvider("anthropic")
                : new StubProvider("anthropic", primaryStatus, primaryBody));
        }
        if (fallbacks.Count > 0)
        {
            allProviders.Add(fallbackThrows
                ? new ThrowingProvider("ollama")
                : new StubProvider("ollama", fallbackStatus, fallbackBody));
        }

        // ModelRouter: aliases that route primary to anthropic, fallbacks to anthropic (no ':')
        var router = new ModelRouter(optsMon);
        var registry = new ProviderRegistry(allProviders);

        var tmpDir = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
        Directory.CreateDirectory(tmpDir);
        var costing = new CostingService(optsMon, Microsoft.Extensions.Logging.Abstractions.NullLogger<CostingService>.Instance, tmpDir);
        var usageQueue = new UsageRecordingQueue(
            costing,
            Microsoft.Extensions.Logging.Abstractions.NullLogger<UsageRecordingQueue>.Instance);

        var svc = new FallbackService(router, registry, optsMon,
            usageQueue, Microsoft.Extensions.Logging.Abstractions.NullLogger<FallbackService>.Instance);

        var ctx = new DefaultHttpContext();
        ctx.Request.Method = "POST";
        ctx.Request.Body = new MemoryStream(Encoding.UTF8.GetBytes("""{"model":"claude-3-opus","messages":[]}"""));
        ctx.Request.EnableBuffering();
        ctx.Response.Body = new MemoryStream();

        return (svc, costing, ctx);
    }

    /// <summary>Test-Provider der immer einen konfigurierten Status + Body liefert.</summary>
    private sealed class StubProvider(string name, int statusCode, string body = "{}") : IProvider
    {
        public string Name => name;

        public async Task ForwardAsync(HttpContext context, string resolvedModel, CancellationToken ct)
        {
            context.Response.StatusCode = statusCode;
            context.Response.ContentType = "application/json";
            await context.Response.Body.WriteAsync(Encoding.UTF8.GetBytes(body), ct);
        }
    }

    /// <summary>Test-Provider der immer eine Exception wirft.</summary>
    private sealed class ThrowingProvider(string name) : IProvider
    {
        public string Name => name;

        public Task ForwardAsync(HttpContext context, string resolvedModel, CancellationToken ct) =>
            throw new HttpRequestException("Simulierter Netzwerkfehler");
    }

    private sealed class ThrowingJsonProvider(string name) : IProvider
    {
        public string Name => name;

        public Task ForwardAsync(HttpContext context, string resolvedModel, CancellationToken ct) =>
            throw new JsonException("Simulierter JSON-Fehler");
    }
}

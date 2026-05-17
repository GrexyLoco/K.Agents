namespace K.Switchboard.Tests.Providers;

/// <summary>
/// Unit-Tests für <see cref="AnthropicProvider"/> und <see cref="OllamaProvider"/>
/// mit Mock-HttpMessageHandler — simuliert das upstream Backend.
/// </summary>
public sealed class ProviderForwardingTests
{
    // --- AnthropicProvider ---

    [Test]
    public async Task AnthropicProvider_ForwardsToAnthropicBaseUrl()
    {
        var capturedUrl = string.Empty;
        var (provider, _) = CreateAnthropicProvider(
            baseUrl: "https://api.anthropic.com",
            onRequest: req => capturedUrl = req.RequestUri?.ToString() ?? string.Empty);

        var ctx = BuildContext("""{"model":"claude-3-opus","messages":[]}""");
        await provider.ForwardAsync(ctx, "claude-3-opus-20240229", CancellationToken.None);

        await Assert.That(capturedUrl).StartsWith("https://api.anthropic.com");
    }

    [Test]
    public async Task AnthropicProvider_RewritesModelInBody()
    {
        var capturedBody = string.Empty;
        var (provider, _) = CreateAnthropicProvider(
            onRequest: async req =>
            {
                capturedBody = req.Content is not null
                    ? await req.Content.ReadAsStringAsync()
                    : string.Empty;
            });

        var ctx = BuildContext("""{"model":"local-coder","messages":[]}""");
        await provider.ForwardAsync(ctx, "claude-3-opus-20240229", CancellationToken.None);

        var doc = JsonDocument.Parse(capturedBody);
        var model = doc.RootElement.GetProperty("model").GetString();
        await Assert.That(model).IsEqualTo("claude-3-opus-20240229");
    }

    [Test]
    public async Task AnthropicProvider_PassesThroughXHeaders()
    {
        var capturedApiKey = string.Empty;
        var (provider, _) = CreateAnthropicProvider(
            onRequest: req =>
            {
                capturedApiKey = req.Headers.TryGetValues("x-api-key", out var values)
                    ? string.Join("", values)
                    : string.Empty;
            });

        var ctx = BuildContext("""{"model":"test","messages":[]}""");
        ctx.Request.Headers["x-api-key"] = "sk-test-123";
        await provider.ForwardAsync(ctx, "test-model", CancellationToken.None);

        await Assert.That(capturedApiKey).IsEqualTo("sk-test-123");
    }

    [Test]
    public async Task AnthropicProvider_SetsResponseStatusCode()
    {
        var (provider, _) = CreateAnthropicProvider(responseCode: HttpStatusCode.Created);

        var ctx = BuildContext("""{"model":"test","messages":[]}""");
        await provider.ForwardAsync(ctx, "test-model", CancellationToken.None);

        await Assert.That(ctx.Response.StatusCode).IsEqualTo(201);
    }

    // --- OllamaProvider ---

    [Test]
    public async Task OllamaProvider_ForwardsToOllamaBaseUrl()
    {
        var capturedUrl = string.Empty;
        var (provider, _) = CreateOllamaProvider(
            baseUrl: "http://localhost:11434",
            onRequest: req => capturedUrl = req.RequestUri?.ToString() ?? string.Empty);

        var ctx = BuildContext("""{"model":"codellama:13b","messages":[]}""");
        await provider.ForwardAsync(ctx, "codellama:13b", CancellationToken.None);

        await Assert.That(capturedUrl).StartsWith("http://localhost:11434");
    }

    [Test]
    public async Task OllamaProvider_RewritesModelInBody()
    {
        var capturedBody = string.Empty;
        var (provider, _) = CreateOllamaProvider(
            onRequest: async req =>
            {
                capturedBody = req.Content is not null
                    ? await req.Content.ReadAsStringAsync()
                    : string.Empty;
            });

        var ctx = BuildContext("""{"model":"local-coder","messages":[]}""");
        await provider.ForwardAsync(ctx, "codellama:13b", CancellationToken.None);

        var doc = JsonDocument.Parse(capturedBody);
        await Assert.That(doc.RootElement.GetProperty("model").GetString()).IsEqualTo("codellama:13b");
    }

    // --- Hilfsmethoden ---

    private static (AnthropicProvider Provider, MockHttpHandler Handler) CreateAnthropicProvider(
        string baseUrl = "https://api.anthropic.com",
        Action<HttpRequestMessage>? onRequest = null,
        HttpStatusCode responseCode = HttpStatusCode.OK)
    {
        var handler = new MockHttpHandler(onRequest, responseCode);
        var factory = new SingleClientFactory(new HttpClient(handler));
        var opts = new FakeOptionsMonitor<SwitchboardOptions>(new SwitchboardOptions
        {
            AnthropicBaseUrl = baseUrl
        });
        return (new AnthropicProvider(factory, opts, NullLogger<AnthropicProvider>.Instance), handler);
    }

    private static (OllamaProvider Provider, MockHttpHandler Handler) CreateOllamaProvider(
        string baseUrl = "http://localhost:11434",
        Action<HttpRequestMessage>? onRequest = null,
        HttpStatusCode responseCode = HttpStatusCode.OK)
    {
        var handler = new MockHttpHandler(onRequest, responseCode);
        var factory = new SingleClientFactory(new HttpClient(handler));
        var opts = new FakeOptionsMonitor<SwitchboardOptions>(new SwitchboardOptions
        {
            OllamaBaseUrl = baseUrl
        });
        return (new OllamaProvider(factory, opts, NullLogger<OllamaProvider>.Instance), handler);
    }

    private static DefaultHttpContext BuildContext(string jsonBody)
    {
        var ctx = new DefaultHttpContext();
        ctx.Request.Method = "POST";
        ctx.Request.ContentType = "application/json";
        ctx.Request.Body = new MemoryStream(Encoding.UTF8.GetBytes(jsonBody));
        ctx.Request.Path = "/v1/messages";
        ctx.Response.Body = new MemoryStream();
        return ctx;
    }
}

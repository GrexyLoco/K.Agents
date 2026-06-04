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
    public async Task AnthropicProvider_DoesNotPassThroughUnknownXHeaders()
    {
        var hasHeader = false;
        var (provider, _) = CreateAnthropicProvider(
            onRequest: req => hasHeader = req.Headers.Contains("x-forward-this"));

        var ctx = BuildContext("""{"model":"test","messages":[]}""");
        ctx.Request.Headers["x-forward-this"] = "secret";
        await provider.ForwardAsync(ctx, "test-model", CancellationToken.None);

        await Assert.That(hasHeader).IsFalse();
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

        await Assert.That(capturedUrl).IsEqualTo("http://localhost:11434/api/chat");
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

    [Test]
    public async Task OllamaProvider_ConvertsAnthropicMessagesAndMaxTokens()
    {
        var capturedBody = string.Empty;
        var (provider, _) = CreateOllamaProvider(
            onRequest: async req =>
            {
                capturedBody = req.Content is not null
                    ? await req.Content.ReadAsStringAsync()
                    : string.Empty;
            });

        var ctx = BuildContext("""
            {
              "model":"local-coder",
              "max_tokens":42,
              "messages":[
                {"role":"user","content":[{"type":"text","text":"Hello"},{"type":"text","text":" World"}]},
                {"role":"assistant","content":"Done"}
              ]
            }
            """);

        await provider.ForwardAsync(ctx, "codellama:13b", CancellationToken.None);

        var doc = JsonDocument.Parse(capturedBody);
        await Assert.That(doc.RootElement.GetProperty("messages")[0].GetProperty("content").GetString()).IsEqualTo("Hello World");
        await Assert.That(doc.RootElement.GetProperty("messages")[1].GetProperty("content").GetString()).IsEqualTo("Done");
        await Assert.That(doc.RootElement.GetProperty("options").GetProperty("num_predict").GetInt32()).IsEqualTo(42);
    }

    [Test]
    public async Task OllamaProvider_ConvertsSuccessResponseToAnthropicShape()
    {
        const string ollamaResponse = """
            {
              "model": "codellama:13b",
              "created_at": "2026-05-17T19:00:00Z",
              "message": { "role": "assistant", "content": "Hallo aus Ollama" },
              "prompt_eval_count": 12,
              "eval_count": 7,
              "done": true
            }
            """;

        var (provider, _) = CreateOllamaProvider(responseBody: ollamaResponse);
        var ctx = BuildContext("""{"model":"codellama:13b","messages":[]}""");

        await provider.ForwardAsync(ctx, "codellama:13b", CancellationToken.None);

        ctx.Response.Body.Position = 0;
        using var reader = new StreamReader(ctx.Response.Body, Encoding.UTF8, leaveOpen: true);
        var payload = await reader.ReadToEndAsync();
        var doc = JsonDocument.Parse(payload);

        await Assert.That(ctx.Response.StatusCode).IsEqualTo(200);
        await Assert.That(doc.RootElement.GetProperty("type").GetString()).IsEqualTo("message");
        await Assert.That(doc.RootElement.GetProperty("model").GetString()).IsEqualTo("codellama:13b");
        await Assert.That(doc.RootElement.GetProperty("content")[0].GetProperty("text").GetString()).IsEqualTo("Hallo aus Ollama");
        await Assert.That(doc.RootElement.GetProperty("usage").GetProperty("input_tokens").GetInt32()).IsEqualTo(12);
        await Assert.That(doc.RootElement.GetProperty("usage").GetProperty("output_tokens").GetInt32()).IsEqualTo(7);
    }

    [Test]
    public async Task OllamaProvider_DoesNotPassThroughXHeaders()
    {
        var hasHeader = false;
        var (provider, _) = CreateOllamaProvider(
            onRequest: req => hasHeader = req.Headers.Contains("x-api-key"));

        var ctx = BuildContext("""{"model":"codellama:13b","messages":[]}""");
        ctx.Request.Headers["x-api-key"] = "should-not-pass";
        await provider.ForwardAsync(ctx, "codellama:13b", CancellationToken.None);

        await Assert.That(hasHeader).IsFalse();
    }

    [Test]
    public async Task OllamaProvider_IncludesDefaultKeepAliveInBody()
    {
        var capturedBody = string.Empty;
        var (provider, _) = CreateOllamaProvider(
            onRequest: async req =>
            {
                capturedBody = req.Content is not null
                    ? await req.Content.ReadAsStringAsync()
                    : string.Empty;
            });

        var ctx = BuildContext("""{"model":"codellama:13b","messages":[]}""");
        await provider.ForwardAsync(ctx, "codellama:13b", CancellationToken.None);

        var doc = JsonDocument.Parse(capturedBody);
        await Assert.That(doc.RootElement.GetProperty("keep_alive").GetString()).IsEqualTo("30m");
    }

    [Test]
    public async Task OllamaProvider_IncludesConfiguredKeepAliveInBody()
    {
        var capturedBody = string.Empty;
        var (provider, _) = CreateOllamaProvider(
            keepAlive: "1h",
            onRequest: async req =>
            {
                capturedBody = req.Content is not null
                    ? await req.Content.ReadAsStringAsync()
                    : string.Empty;
            });

        var ctx = BuildContext("""{"model":"codellama:13b","messages":[]}""");
        await provider.ForwardAsync(ctx, "codellama:13b", CancellationToken.None);

        var doc = JsonDocument.Parse(capturedBody);
        await Assert.That(doc.RootElement.GetProperty("keep_alive").GetString()).IsEqualTo("1h");
    }

    [Test]
    public async Task SwitchboardOptions_HasExpectedOllamaDefaults()
    {
        var options = new SwitchboardOptions();

        await Assert.That(options.OllamaTimeoutSeconds).IsEqualTo(600);
        await Assert.That(options.OllamaKeepAlive).IsEqualTo("30m");
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
        HttpStatusCode responseCode = HttpStatusCode.OK,
        string responseBody = "{}",
        string keepAlive = "30m")
    {
        var handler = new MockHttpHandler(onRequest, responseCode, responseBody);
        var factory = new SingleClientFactory(new HttpClient(handler));
        var opts = new FakeOptionsMonitor<SwitchboardOptions>(new SwitchboardOptions
        {
            OllamaBaseUrl = baseUrl,
            OllamaKeepAlive = keepAlive
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

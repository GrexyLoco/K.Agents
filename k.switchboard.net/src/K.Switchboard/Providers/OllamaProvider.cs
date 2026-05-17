namespace K.Switchboard.Providers;

/// <summary>
/// Provider für Ollama — leitet Requests an das konfigurierte Ollama-Backend weiter,
/// inklusive Streaming-Antworten.
/// </summary>
public sealed class OllamaProvider(
    IHttpClientFactory httpClientFactory,
    IOptionsMonitor<SwitchboardOptions> options,
    ILogger<OllamaProvider> logger) : IProvider
{
    /// <inheritdoc />
    public string Name => "ollama";

    /// <inheritdoc />
    public async Task ForwardAsync(HttpContext context, string resolvedModel, CancellationToken cancellationToken)
    {
        var opts = options.CurrentValue;
        var upstreamUrl = opts.OllamaBaseUrl.TrimEnd('/') + context.Request.Path + context.Request.QueryString;

        logger.LogDebug("Forwarding {Method} to Ollama: {Url} (model: {Model})",
            context.Request.Method, upstreamUrl, resolvedModel);

        var client = httpClientFactory.CreateClient(Name);
        using var upstreamRequest = new HttpRequestMessage(new HttpMethod(context.Request.Method), upstreamUrl);

        upstreamRequest.Content = await BuildContentAsync(context.Request.Body, resolvedModel, cancellationToken);

        foreach (var header in context.Request.Headers)
        {
            if (ShouldPassThrough(header.Key))
                upstreamRequest.Headers.TryAddWithoutValidation(header.Key, header.Value.ToArray());
        }

        using var response = await client.SendAsync(
            upstreamRequest, HttpCompletionOption.ResponseHeadersRead, cancellationToken);

        context.Response.StatusCode = (int)response.StatusCode;

        foreach (var header in response.Headers)
            context.Response.Headers.TryAdd(header.Key, header.Value.ToArray());
        foreach (var header in response.Content.Headers)
            context.Response.Headers.TryAdd(header.Key, header.Value.ToArray());

        context.Response.Headers.Remove("transfer-encoding");

        await response.Content.CopyToAsync(context.Response.Body, cancellationToken);
    }

    private static async Task<StringContent> BuildContentAsync(Stream body, string resolvedModel, CancellationToken ct)
    {
        using var reader = new StreamReader(body, Encoding.UTF8, leaveOpen: true);
        var json = await reader.ReadToEndAsync(ct);

        if (JsonNode.Parse(json) is JsonObject obj)
        {
            obj["model"] = resolvedModel;
            json = obj.ToJsonString();
        }

        return new StringContent(json, Encoding.UTF8, "application/json");
    }

    private static bool ShouldPassThrough(string headerName) =>
        headerName.StartsWith("x-", StringComparison.OrdinalIgnoreCase) ||
        headerName.Equals("authorization", StringComparison.OrdinalIgnoreCase);
}

namespace K.Switchboard.Providers;

/// <summary>
/// Provider für Anthropic Claude API — leitet Requests als Pass-through weiter,
/// inklusive SSE-Streaming-Antworten.
/// </summary>
public sealed class AnthropicProvider(
    IHttpClientFactory httpClientFactory,
    IOptionsMonitor<SwitchboardOptions> options,
    ILogger<AnthropicProvider> logger) : IProvider
{
    /// <inheritdoc />
    public string Name => "anthropic";

    /// <inheritdoc />
    public async Task ForwardAsync(HttpContext context, string resolvedModel, CancellationToken cancellationToken)
    {
        var opts = options.CurrentValue;
        var upstreamUrl = opts.AnthropicBaseUrl.TrimEnd('/') + context.Request.Path + context.Request.QueryString;

        logger.LogDebug("Forwarding {Method} to Anthropic: {Url} (model: {Model})",
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

        // Transfer-Encoding entfernen — ASP.NET Core setzt es selbst korrekt
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
        headerName.Equals("x-api-key", StringComparison.OrdinalIgnoreCase) ||
        headerName.Equals("anthropic-version", StringComparison.OrdinalIgnoreCase) ||
        headerName.Equals("anthropic-beta", StringComparison.OrdinalIgnoreCase) ||
        headerName.Equals("authorization", StringComparison.OrdinalIgnoreCase);
}

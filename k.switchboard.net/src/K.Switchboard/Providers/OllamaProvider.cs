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

    private const string AnthropicMessageType = "message";
    private const string AnthropicAssistantRole = "assistant";
    private const string AnthropicTextType = "text";
    private const string AnthropicTextDeltaType = "text_delta";

    /// <inheritdoc />
    public async Task ForwardAsync(HttpContext context, string resolvedModel, CancellationToken cancellationToken)
    {
        var opts = options.CurrentValue;
        var upstreamUrl = opts.OllamaBaseUrl.TrimEnd('/') + "/api/chat";

        var (ollamaBody, isStreaming) = await BuildOllamaBodyAsync(context.Request.Body, resolvedModel, opts.OllamaKeepAlive, cancellationToken);

        logger.LogDebug("Forwarding {Method} to Ollama: {Url} (model: {Model})",
            context.Request.Method, upstreamUrl, resolvedModel);

        var client = httpClientFactory.CreateClient(Name);
        using var upstreamRequest = new HttpRequestMessage(HttpMethod.Post, upstreamUrl)
        {
            Content = new StringContent(ollamaBody.ToJsonString(), Encoding.UTF8, "application/json")
        };

        foreach (var header in context.Request.Headers)
        {
            if (ShouldPassThrough(header.Key))
                upstreamRequest.Headers.TryAddWithoutValidation(header.Key, header.Value.ToArray());
        }

        using var response = await client.SendAsync(
            upstreamRequest, HttpCompletionOption.ResponseHeadersRead, cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            await CopyRawResponseAsync(context, response, cancellationToken);
            return;
        }

        if (isStreaming)
        {
            await WriteStreamingAnthropicResponseAsync(context, response, resolvedModel, cancellationToken);
            return;
        }

        await WriteJsonAnthropicResponseAsync(context, response, cancellationToken);
    }

    private static async Task<(JsonObject Body, bool IsStreaming)> BuildOllamaBodyAsync(Stream body, string resolvedModel, string keepAlive, CancellationToken ct)
    {
        using var reader = new StreamReader(body, Encoding.UTF8, leaveOpen: true);
        var json = await reader.ReadToEndAsync(ct);

        var request = JsonNode.Parse(json) as JsonObject ?? new JsonObject();
        var isStreaming = request["stream"]?.GetValue<bool>() ?? false;

        var messages = new JsonArray();
        if (request["messages"] is JsonArray inputMessages)
        {
            foreach (var node in inputMessages)
            {
                if (node is not JsonObject message)
                    continue;

                var role = message["role"]?.GetValue<string>() ?? "user";
                var content = ExtractMessageText(message["content"]);
                JsonNode messageNode = new JsonObject
                {
                    ["role"] = role,
                    ["content"] = content
                };
                messages.Add(messageNode);
            }
        }

        var ollamaBody = new JsonObject
        {
            ["model"] = resolvedModel,
            ["messages"] = messages,
            ["stream"] = isStreaming,
            ["keep_alive"] = keepAlive
        };

        if (request["max_tokens"]?.GetValue<int?>() is int maxTokens)
        {
            ollamaBody["options"] = new JsonObject { ["num_predict"] = maxTokens };
        }

        return (ollamaBody, isStreaming);
    }

    private static string ExtractMessageText(JsonNode? content)
    {
        if (content is null)
            return string.Empty;

        if (content is JsonValue value && value.TryGetValue<string>(out var text))
            return text;

        if (content is JsonArray blocks)
        {
            var sb = new StringBuilder();
            foreach (var block in blocks)
            {
                if (block is JsonObject obj &&
                    string.Equals(obj["type"]?.GetValue<string>(), AnthropicTextType, StringComparison.Ordinal) &&
                    obj["text"]?.GetValue<string>() is string part)
                {
                    sb.Append(part);
                }
            }

            return sb.ToString();
        }

        if (content is JsonObject objectValue)
            return objectValue["text"]?.GetValue<string>() ?? string.Empty;

        return string.Empty;
    }

    private static async Task WriteJsonAnthropicResponseAsync(HttpContext context, HttpResponseMessage response, CancellationToken ct)
    {
        var raw = await response.Content.ReadAsStringAsync(ct);
        var ollama = JsonNode.Parse(raw) as JsonObject ?? new JsonObject();
        var anthropic = ConvertOllamaToAnthropicMessage(ollama);

        context.Response.StatusCode = StatusCodes.Status200OK;
        context.Response.ContentType = "application/json";
        await context.Response.WriteAsync(anthropic.ToJsonString(), ct);
    }

    private static async Task WriteStreamingAnthropicResponseAsync(HttpContext context, HttpResponseMessage response, string resolvedModel, CancellationToken ct)
    {
        context.Response.StatusCode = (int)response.StatusCode;
        context.Response.ContentType = "text/event-stream";

        var messageId = $"msg_ollama_{resolvedModel.Replace(':', '_')}";
        await WriteSseAsync(context, new JsonObject
        {
            ["type"] = "message_start",
            ["message"] = new JsonObject
            {
                ["id"] = messageId,
                ["type"] = AnthropicMessageType,
                ["role"] = AnthropicAssistantRole,
                ["content"] = new JsonArray(),
                ["model"] = resolvedModel,
                ["stop_reason"] = null,
                ["stop_sequence"] = null,
                ["usage"] = new JsonObject
                {
                    ["input_tokens"] = 0,
                    ["output_tokens"] = 0
                }
            }
        }, ct);

        await WriteSseAsync(context, new JsonObject
        {
            ["type"] = "content_block_start",
            ["index"] = 0,
            ["content_block"] = new JsonObject
            {
                ["type"] = AnthropicTextType,
                ["text"] = string.Empty
            }
        }, ct);

        await using var stream = await response.Content.ReadAsStreamAsync(ct);
        using var reader = new StreamReader(stream, Encoding.UTF8);

        while (true)
        {
            var line = await reader.ReadLineAsync(ct);
            if (line is null)
                break;

            if (string.IsNullOrWhiteSpace(line))
                continue;

            JsonObject? chunk;
            try
            {
                chunk = JsonNode.Parse(line) as JsonObject;
            }
            catch (JsonException)
            {
                continue;
            }

            if (chunk is null)
                continue;

            var delta = chunk["message"]?["content"]?.GetValue<string>();
            if (!string.IsNullOrEmpty(delta))
            {
                await WriteSseAsync(context, new JsonObject
                {
                    ["type"] = "content_block_delta",
                    ["index"] = 0,
                    ["delta"] = new JsonObject
                    {
                        ["type"] = AnthropicTextDeltaType,
                        ["text"] = delta
                    }
                }, ct);
            }

            if (chunk["done"]?.GetValue<bool>() == true)
            {
                var usage = new JsonObject
                {
                    ["input_tokens"] = chunk["prompt_eval_count"]?.GetValue<int>() ?? 0,
                    ["output_tokens"] = chunk["eval_count"]?.GetValue<int>() ?? 0
                };

                await WriteSseAsync(context, new JsonObject
                {
                    ["type"] = "content_block_stop",
                    ["index"] = 0
                }, ct);

                await WriteSseAsync(context, new JsonObject
                {
                    ["type"] = "message_delta",
                    ["delta"] = new JsonObject
                    {
                        ["stop_reason"] = "end_turn",
                        ["stop_sequence"] = null
                    },
                    ["usage"] = usage
                }, ct);

                await WriteSseAsync(context, new JsonObject { ["type"] = "message_stop" }, ct);
                await context.Response.WriteAsync("data: [DONE]\n\n", ct);
                await context.Response.Body.FlushAsync(ct);
                return;
            }
        }
    }

    private static async Task WriteSseAsync(HttpContext context, JsonObject payload, CancellationToken ct)
    {
        await context.Response.WriteAsync($"data: {payload.ToJsonString()}\n\n", ct);
        await context.Response.Body.FlushAsync(ct);
    }

    private static async Task CopyRawResponseAsync(HttpContext context, HttpResponseMessage response, CancellationToken ct)
    {
        context.Response.StatusCode = (int)response.StatusCode;

        foreach (var header in response.Headers)
            context.Response.Headers.TryAdd(header.Key, header.Value.ToArray());
        foreach (var header in response.Content.Headers)
            context.Response.Headers.TryAdd(header.Key, header.Value.ToArray());

        context.Response.Headers.Remove("transfer-encoding");
        await response.Content.CopyToAsync(context.Response.Body, ct);
    }

    private static JsonObject ConvertOllamaToAnthropicMessage(JsonObject ollama)
    {
        var model = ollama["model"]?.GetValue<string>() ?? "unknown";
        var messageText = ollama["message"]?["content"]?.GetValue<string>() ?? string.Empty;
        var createdAt = ollama["created_at"]?.GetValue<string>() ?? "unknown";
        var inputTokens = ollama["prompt_eval_count"]?.GetValue<int>() ?? 0;
        var outputTokens = ollama["eval_count"]?.GetValue<int>() ?? 0;

        JsonNode contentNode = new JsonObject
        {
            ["type"] = AnthropicTextType,
            ["text"] = messageText
        };

        var contentArray = new JsonArray();
        contentArray.Add(contentNode);

        return new JsonObject
        {
            ["id"] = $"msg_ollama_{createdAt}",
            ["type"] = AnthropicMessageType,
            ["role"] = AnthropicAssistantRole,
            ["content"] = contentArray,
            ["model"] = model,
            ["stop_reason"] = "end_turn",
            ["stop_sequence"] = null,
            ["usage"] = new JsonObject
            {
                ["input_tokens"] = inputTokens,
                ["output_tokens"] = outputTokens
            }
        };
    }

    private static bool ShouldPassThrough(string headerName) =>
        headerName.Equals("authorization", StringComparison.OrdinalIgnoreCase);
}

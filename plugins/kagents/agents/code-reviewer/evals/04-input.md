# Code-Review-Input 04 — code-reviewer

**Aufgabe:** Reviewe den folgenden Code-Ausschnitt. Nenne konkrete Findings mit Severity (Blocker/Wichtig/Verbesserung/Hinweis), Datei:Zeile, Problem und Empfehlung. Auf Deutsch.
**Datei:** `k.switchboard.net/src/K.Switchboard/Providers/OllamaProvider.cs` (Zeilen 61–131) — *Ollama-Body-Bau (static) + Text-Extraktion*

```csharp
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
```

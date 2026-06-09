namespace K.Switchboard;

using System.Text.Json;

/// <summary>Grobe Input-Token-Schätzung (~4 Zeichen/Token) aus dem Anthropic-Request-Body
/// für die ResourceGate-Latenz-Vorhersage. Best-effort, keine echte Tokenisierung.</summary>
public static class RequestTokenEstimator
{
    /// <summary>Summe der messages[].content-Längen / 4. 0 wenn nicht ermittelbar.</summary>
    public static int EstimateInputTokens(JsonElement root)
    {
        if (!root.TryGetProperty("messages", out var messages) || messages.ValueKind != JsonValueKind.Array)
            return 0;

        var chars = 0;
        foreach (var m in messages.EnumerateArray())
        {
            if (!m.TryGetProperty("content", out var content)) continue;
            if (content.ValueKind == JsonValueKind.String)
            {
                chars += content.GetString()?.Length ?? 0;
            }
            else if (content.ValueKind == JsonValueKind.Array)
            {
                foreach (var block in content.EnumerateArray())
                    if (block.TryGetProperty("text", out var t) && t.ValueKind == JsonValueKind.String)
                        chars += t.GetString()?.Length ?? 0;
            }
        }
        return chars / 4;
    }
}

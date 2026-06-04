namespace K.Switchboard;

/// <summary>Zentrale Konfigurationsoptionen für K.Switchboard.</summary>
public sealed record SwitchboardOptions
{
    /// <summary>Port, auf dem K.Switchboard lauscht.</summary>
    public int Port { get; init; } = 3456;

    /// <summary>Basis-URL des Anthropic-API-Endpunkts.</summary>
    public string AnthropicBaseUrl { get; init; } = "https://api.anthropic.com";

    /// <summary>Basis-URL des Ollama-Endpunkts.</summary>
    public string OllamaBaseUrl { get; init; } = "http://localhost:11434";

    /// <summary>Timeout für Ollama-Forwarding in Sekunden (lokale Inferenz kann lange dauern).</summary>
    public int OllamaTimeoutSeconds { get; init; } = 600;

    /// <summary>keep_alive-Wert für Ollama (wie lange das Modell nach einem Request geladen bleibt).</summary>
    public string OllamaKeepAlive { get; init; } = "30m";

    /// <summary>Optionaler API-Key für den Zugriff auf den Proxy-Endpunkt.</summary>
    public string? ApiKey { get; init; }

    /// <summary>Maximale Requests pro Zeitfenster für den Proxy-Endpunkt.</summary>
    public int RateLimitPermitLimit { get; init; } = 120;

    /// <summary>Zeitfenster in Minuten für das Rate-Limit.</summary>
    public int RateLimitWindowMinutes { get; init; } = 1;

    /// <summary>Alias-Mapping von Modellnamen auf Provider-Modelle.</summary>
    public Dictionary<string, string> ModelAliases { get; init; } = [];

    /// <summary>Fallback-Ketten pro Modell-Alias (geordnete Provider-Liste).</summary>
    public Dictionary<string, List<string>> FallbackChains { get; init; } = [];

    /// <summary>Maximale Anzahl von Fallback-Einträgen, die pro Request berücksichtigt werden.</summary>
    public int FallbackMaxDepth { get; init; } = 8;

    /// <summary>Kosten-Konfiguration (Input/Output pro Million Tokens in USD).</summary>
    public Dictionary<string, ModelPricing> Pricing { get; init; } = [];
}

/// <summary>Preis-Konfiguration für ein Modell.</summary>
public sealed record ModelPricing
{
    /// <summary>Kosten pro 1M Input-Tokens in USD.</summary>
    public decimal InputPerMillion { get; init; }

    /// <summary>Kosten pro 1M Output-Tokens in USD.</summary>
    public decimal OutputPerMillion { get; init; }
}

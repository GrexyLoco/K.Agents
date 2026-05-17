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

    /// <summary>Alias-Mapping von Modellnamen auf Provider-Modelle.</summary>
    public Dictionary<string, string> ModelAliases { get; init; } = [];

    /// <summary>Fallback-Ketten pro Modell-Alias (geordnete Provider-Liste).</summary>
    public Dictionary<string, List<string>> FallbackChains { get; init; } = [];

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

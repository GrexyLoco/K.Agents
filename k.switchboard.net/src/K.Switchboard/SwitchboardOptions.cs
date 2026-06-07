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

    /// <summary>Ordnet jedem Ollama-Modell das Claude-Modell zu, das es vertritt
    /// (Baseline für die Ersparnis-Berechnung). Key = Ollama-Modellname (mit ':'),
    /// Value = Claude-Modellname, der als Pricing-Key in <see cref="Pricing"/> existieren muss.</summary>
    public Dictionary<string, string> SavingsBaseline { get; init; } = [];

    /// <summary>Lokales Ollama-Modell → Aufgaben-Tier (S/M/L). Basis für die Substitution.</summary>
    public Dictionary<string, string> LocalModelTiers { get; init; } = [];

    /// <summary>Tier (S/M/L) → Claude-Substitut-Modell, falls das lokale Modell nicht ausführbar ist.</summary>
    public Dictionary<string, string> TierSubstitutions { get; init; } = [];

    /// <summary>Kuratierte HW-Klassen (committed): welche lokalen Modelle pro Klasse tauglich sind.</summary>
    public List<HardwareClassConfig> HardwareClasses { get; init; } = [];

    /// <summary>Einstellungen des ResourceGate (Pre-flight-Ressourcen-Check).</summary>
    public ResourceGateOptions ResourceGate { get; init; } = new();

    /// <summary>Auslieferungs-Defaults für eine Neuinstallation (committed Mapping b + Substitution +
    /// aktiviertes ResourceGate). Bestehende config.json bleiben unberührt → Gate bleibt aus, solange
    /// keine ResourceGate-Sektion vorhanden ist (Enabled-Default = false).</summary>
    public static SwitchboardOptions CreateDefault() => new()
    {
        LocalModelTiers = new()
        {
            ["qwen2.5-coder:1.5b"] = "S", ["llama3.2:3b"] = "S",
            ["qwen2.5-coder:7b"] = "M",  ["llama3.1:8b"] = "M",
            ["qwen2.5-coder:14b"] = "L", ["qwen2.5-coder:32b"] = "L"
        },
        TierSubstitutions = new()
        {
            ["S"] = "claude-haiku-4-5", ["M"] = "claude-sonnet-4-6", ["L"] = "claude-sonnet-4-6"
        },
        ResourceGate = new ResourceGateOptions { Enabled = true, RamBufferMb = 0, CpuLoadWindowSeconds = 4, CpuMaxLoadPercent = 85 },
        HardwareClasses =
        [
            new() { Name = "cpu-low",      Match = new() { MaxRamMb = 16384 } },
            new() { Name = "gpu-7b",       Match = new() { MinVramMb = 6144,  MaxVramMb = 10239 } },
            new() { Name = "gpu-14b",      Match = new() { MinVramMb = 10240, MaxVramMb = 16383 } },
            new() { Name = "gpu-14b-plus", Match = new() { MinVramMb = 16384 } },
            new() { Name = "cpu-32",       Match = new() { MinRamMb = 24576 } }
        ]
    };
}

/// <summary>Preis-Konfiguration für ein Modell.</summary>
public sealed record ModelPricing
{
    /// <summary>Kosten pro 1M Input-Tokens in USD.</summary>
    public decimal InputPerMillion { get; init; }

    /// <summary>Kosten pro 1M Output-Tokens in USD.</summary>
    public decimal OutputPerMillion { get; init; }
}

/// <summary>Eine kuratierte HW-Klasse: Match-Kriterien + tauglich-validierte Modelle.</summary>
public sealed record HardwareClassConfig
{
    /// <summary>Eindeutiger Klassenname (z.B. "gpu-14b", "cpu-low").</summary>
    public string Name { get; init; } = string.Empty;

    /// <summary>Match-Kriterien gegen das erkannte HW-Profil.</summary>
    public HardwareClassMatch Match { get; init; } = new();

    /// <summary>Tauglich-validierte lokale Modelle dieser Klasse (Key = Ollama-Modellname).
    /// Leer = keine lokalen Modelle tauglich → immer substituieren.</summary>
    public Dictionary<string, ModelValidation> Models { get; init; } = [];
}

/// <summary>Match-Kriterien einer HW-Klasse. Null-Felder werden ignoriert (kein Constraint).</summary>
public sealed record HardwareClassMatch
{
    /// <summary>Minimaler Gesamt-RAM in MB (inklusive).</summary>
    public int? MinRamMb { get; init; }

    /// <summary>Maximaler Gesamt-RAM in MB (inklusive).</summary>
    public int? MaxRamMb { get; init; }

    /// <summary>Minimale CPU-Kernzahl (inklusive).</summary>
    public int? MinCores { get; init; }

    /// <summary>GPU-Vendor: "NVIDIA", "AMD" oder "none". Null = egal.</summary>
    public string? GpuVendor { get; init; }

    /// <summary>Minimaler VRAM in MB (inklusive).</summary>
    public int? MinVramMb { get; init; }

    /// <summary>Maximaler VRAM in MB (inklusive).</summary>
    public int? MaxVramMb { get; init; }
}

/// <summary>Empirische Validierungs-Daten eines lokalen Modells auf einer HW-Klasse.</summary>
public sealed record ModelValidation
{
    /// <summary>Beobachteter Peak-RAM (MB) beim realistischen Max-Kontext.
    /// 0 = nicht validiert → lokale Ausführung gesperrt (ResourceGate erzwingt Substitution).</summary>
    public int PeakRamMb { get; init; }

    /// <summary>Setup-Beschreibung, auf dem gemessen wurde (Reproduzierbarkeit, siehe eval-measurement.md).</summary>
    public string ValidatedOn { get; init; } = string.Empty;

    /// <summary>Median-Latenz (ms) im Eval. 0 = nicht gemessen.</summary>
    public int LatencyP50Ms { get; init; }

    /// <summary>Qualitäts-Score (A/B/C/F) aus dem Eval. Leer = nicht bewertet.</summary>
    public string Score { get; init; } = string.Empty;
}

/// <summary>Einstellungen des ResourceGate.</summary>
public sealed record ResourceGateOptions
{
    /// <summary>Gate aktiv? Default false → backward-kompatibel (fehlende Config = Gate aus).</summary>
    public bool Enabled { get; init; }

    /// <summary>Zusätzlicher RAM-Sicherheitspuffer (MB) über PeakRamMb. 0 = im Code hergeleiteter Default.</summary>
    public int RamBufferMb { get; init; }

    /// <summary>Fenster (Sekunden) für den rollenden CPU-Last-Mittelwert.</summary>
    public int CpuLoadWindowSeconds { get; init; } = 4;

    /// <summary>CPU-Last-Schwelle (%), oberhalb derer lokale Inferenz blockiert wird.</summary>
    public int CpuMaxLoadPercent { get; init; } = 85;
}

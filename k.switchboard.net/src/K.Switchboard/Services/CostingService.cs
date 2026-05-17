namespace K.Switchboard.Services;

/// <summary>Nutzungsstatistik eines Modells für einen Tag.</summary>
public sealed class ModelUsage
{
    /// <summary>Anzahl der Input-Tokens.</summary>
    public int InputTokens { get; set; }

    /// <summary>Anzahl der Output-Tokens.</summary>
    public int OutputTokens { get; set; }

    /// <summary>Berechnete Kosten in USD.</summary>
    public decimal CostUsd { get; set; }
}

/// <summary>Tages-Statistik über alle Modelle.</summary>
public sealed record DailyStats(
    DateOnly Date,
    Dictionary<string, ModelUsage> Models,
    decimal TotalCostUsd);

/// <summary>
/// Erfasst Token-Nutzung und berechnet Tages-Kosten anhand der konfigurierten Preise.
/// </summary>
/// <remarks>
/// Persistiert Statistiken in <c>%APPDATA%\K.Switchboard\costs-{yyyy-MM-dd}.json</c>.
/// Thread-sicher via internem Lock.
/// </remarks>
public sealed class CostingService(
    IOptionsMonitor<SwitchboardOptions> options,
    ILogger<CostingService> logger,
    string? baseDirectory = null)
{
    private readonly SemaphoreSlim _lock = new(1, 1);

    private string BaseDirectory => baseDirectory ?? Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "K.Switchboard");

    /// <summary>
    /// Extrahiert Token-Nutzung aus dem Antwort-Body und speichert die Tagesstatistik.
    /// </summary>
    /// <param name="model">Verwendetes Modell.</param>
    /// <param name="responseBody">Rohe Response-Bytes des Providers.</param>
    public async Task RecordUsageAsync(string model, byte[] responseBody)
    {
        if (!TryExtractUsage(responseBody, out var inputTokens, out var outputTokens))
            return;

        var cost = CalculateCost(model, inputTokens, outputTokens);
        var path = GetCostsFilePath(BaseDirectory);

        await _lock.WaitAsync();
        try
        {
            var data = LoadStats(path);
            if (!data.TryGetValue(model, out var stats))
                data[model] = stats = new ModelUsage();

            stats.InputTokens += inputTokens;
            stats.OutputTokens += outputTokens;
            stats.CostUsd += cost;

            await SaveStatsAsync(path, data);
        }
        catch (Exception ex)
        {
            logger.LogError(ex,
                "Nutzungsdaten konnten nicht gespeichert werden (Modell: {Model})", model);
        }
        finally
        {
            _lock.Release();
        }

        logger.LogDebug(
            "Nutzung erfasst: Modell={Model}, Input={Input}, Output={Output}, Kosten={Cost:F6} USD",
            model, inputTokens, outputTokens, cost);
    }

    /// <summary>Gibt die aggregierten Tages-Statistiken des aktuellen UTC-Tages zurück.</summary>
    public DailyStats GetDailyStats()
    {
        var data = LoadStats(GetCostsFilePath(BaseDirectory));
        var total = data.Values.Aggregate(0m, (sum, s) => sum + s.CostUsd);
        return new DailyStats(
            Date: DateOnly.FromDateTime(DateTime.UtcNow),
            Models: data,
            TotalCostUsd: Math.Round(total, 6));
    }

    internal decimal CalculateCost(string model, int inputTokens, int outputTokens)
    {
        if (!options.CurrentValue.Pricing.TryGetValue(model, out var pricing))
            return 0m;
        return inputTokens * pricing.InputPerMillion / 1_000_000m
             + outputTokens * pricing.OutputPerMillion / 1_000_000m;
    }

    internal static bool TryExtractUsage(byte[] body, out int inputTokens, out int outputTokens)
    {
        inputTokens = 0;
        outputTokens = 0;
        if (body is not { Length: > 0 }) return false;

        try
        {
            using var doc = JsonDocument.Parse(body);
            if (!doc.RootElement.TryGetProperty("usage", out var usage)) return false;

            inputTokens = usage.TryGetProperty("input_tokens", out var inp) ? inp.GetInt32() : 0;
            outputTokens = usage.TryGetProperty("output_tokens", out var outp) ? outp.GetInt32() : 0;
            return inputTokens > 0 || outputTokens > 0;
        }
        catch
        {
            return false;
        }
    }

    private static string GetCostsFilePath(string baseDir)
    {
        Directory.CreateDirectory(baseDir);
        return Path.Combine(baseDir, $"costs-{DateTime.UtcNow:yyyy-MM-dd}.json");
    }

    private static Dictionary<string, ModelUsage> LoadStats(string path)
    {
        if (!File.Exists(path)) return [];
        try
        {
            return JsonSerializer.Deserialize<Dictionary<string, ModelUsage>>(
                File.ReadAllText(path)) ?? [];
        }
        catch
        {
            return [];
        }
    }

    private static async Task SaveStatsAsync(string path, Dictionary<string, ModelUsage> data)
    {
        var tmp = path + ".tmp";
        await File.WriteAllTextAsync(tmp,
            JsonSerializer.Serialize(data, new JsonSerializerOptions { WriteIndented = true }));
        File.Move(tmp, path, overwrite: true);
    }
}

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

    /// <summary>
    /// ≈ geschätzte Ersparnis ("avoided cost") in USD: was die erfassten Token beim
    /// Baseline-Claude-Modell gekostet hätten, wenn dieses Modell ein Ollama-Modell mit
    /// konfigurierter <see cref="SwitchboardOptions.SavingsBaseline"/> ist. Schätzung —
    /// Ollama nutzt einen anderen Tokenizer als Claude (siehe docs/monitoring.md).
    /// </summary>
    public decimal SavedUsd { get; set; }

    /// <summary>Claude-Referenzmodell, gegen das die Ersparnis berechnet wurde (falls vorhanden).</summary>
    public string? BaselineModel { get; set; }
}

/// <summary>Tages-Statistik über alle Modelle.</summary>
public sealed record DailyStats(
    DateOnly Date,
    Dictionary<string, ModelUsage> Models,
    decimal TotalCostUsd,
    decimal TotalSavedUsd);

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

        // ≈ geschätzte Ersparnis ("avoided cost"): vertritt dieses (Ollama-)Modell ein
        // Claude-Modell (SavingsBaseline) und ist dessen Pricing bekannt, berechne was die
        // erfassten Token bei der Baseline gekostet hätten. Schätzung — Ollama nutzt einen
        // anderen Tokenizer als Claude, Output-Längen unterscheiden sich (siehe monitoring.md).
        var saved = 0m;
        string? baselineModel = null;
        var cfg = options.CurrentValue;
        if (cfg.SavingsBaseline.TryGetValue(model, out var baseline)
            && cfg.Pricing.TryGetValue(baseline, out var basePricing))
        {
            baselineModel = baseline;
            saved = inputTokens * basePricing.InputPerMillion / 1_000_000m
                  + outputTokens * basePricing.OutputPerMillion / 1_000_000m;
        }

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
            stats.SavedUsd += saved;
            if (baselineModel is not null)
                stats.BaselineModel = baselineModel;

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
            "Nutzung erfasst: Modell={Model}, Input={Input}, Output={Output}, Kosten={Cost:F6} USD, "
            + "Ersparnis≈{Saved:F6} USD (Baseline={Baseline})",
            model, inputTokens, outputTokens, cost, saved, baselineModel ?? "-");
    }

    /// <summary>Gibt die aggregierten Tages-Statistiken des aktuellen UTC-Tages zurück.</summary>
    public DailyStats GetDailyStats()
    {
        var data = LoadStats(GetCostsFilePath(BaseDirectory));
        var total = data.Values.Aggregate(0m, (sum, s) => sum + s.CostUsd);
        var totalSaved = data.Values.Aggregate(0m, (sum, s) => sum + s.SavedUsd);
        return new DailyStats(
            Date: DateOnly.FromDateTime(DateTime.UtcNow),
            Models: data,
            TotalCostUsd: Math.Round(total, 6),
            TotalSavedUsd: Math.Round(totalSaved, 6));
    }

    internal decimal CalculateCost(string model, int inputTokens, int outputTokens)
    {
        if (!options.CurrentValue.Pricing.TryGetValue(model, out var pricing))
            return 0m;
        return inputTokens * pricing.InputPerMillion / 1_000_000m
             + outputTokens * pricing.OutputPerMillion / 1_000_000m;
    }

    /// <summary>
    /// Extrahiert Token-Nutzung sowohl aus einer NICHT-gestreamten Einzel-JSON-Response
    /// (Top-Level <c>usage</c>) als auch aus einem Anthropic-/Ollama-SSE-Eventstrom
    /// (<c>data: {...}</c>-Zeilen).
    /// </summary>
    /// <remarks>
    /// SSE-Akkumulation per MAXIMUM je Feld über ALLE <c>usage</c>-Vorkommen (Top-Level und
    /// unter <c>message</c>): Anthropic-<c>output_tokens</c> ist kumulativ-monoton (max=final),
    /// Anthropic-<c>input_tokens</c> steht im <c>message_start</c>, Ollama liefert die echten
    /// Werte erst im finalen <c>message_delta</c> (max ignoriert die 0 aus dem Start).
    /// Nutzt nur <see cref="JsonDocument"/> (kein Reflection-Serializer) — trim-/AOT-sicher.
    /// </remarks>
    internal static bool TryExtractUsage(byte[] body, out int inputTokens, out int outputTokens)
    {
        inputTokens = 0;
        outputTokens = 0;
        if (body is not { Length: > 0 }) return false;

        // 1) Erstversuch: einzelnes JSON-Objekt (non-streaming, Top-Level usage).
        //    Bei mehrzeilig formatiertem JSON funktioniert das ebenfalls.
        try
        {
            using var doc = JsonDocument.Parse(body);
            AccumulateUsage(doc.RootElement, ref inputTokens, ref outputTokens);
            return inputTokens > 0 || outputTokens > 0;
        }
        catch (JsonException)
        {
            // Kein einzelnes JSON → vermutlich SSE-Eventstrom (data: {...}-Zeilen).
        }

        // 2) SSE-Fallback: zeilenweise jede "data: {json}"-Zeile parsen.
        var text = Encoding.UTF8.GetString(body);
        foreach (var rawLine in text.Split('\n'))
        {
            var line = rawLine.TrimEnd('\r');
            if (!line.StartsWith("data:", StringComparison.Ordinal)) continue;

            var payload = line["data:".Length..].Trim();
            if (payload.Length == 0 || payload == "[DONE]") continue;

            try
            {
                using var doc = JsonDocument.Parse(payload);
                AccumulateUsage(doc.RootElement, ref inputTokens, ref outputTokens);
            }
            catch (JsonException)
            {
                // Nicht-JSON-Eventzeile robust ignorieren.
            }
        }

        return inputTokens > 0 || outputTokens > 0;
    }

    /// <summary>
    /// Sucht <c>usage</c> sowohl auf Top-Level als auch unter <c>message</c> und akkumuliert
    /// <c>input_tokens</c>/<c>output_tokens</c> je als MAXIMUM.
    /// </summary>
    private static void AccumulateUsage(JsonElement root, ref int inputTokens, ref int outputTokens)
    {
        if (root.ValueKind != JsonValueKind.Object) return;

        if (root.TryGetProperty("usage", out var topUsage))
            ApplyUsage(topUsage, ref inputTokens, ref outputTokens);

        if (root.TryGetProperty("message", out var message)
            && message.ValueKind == JsonValueKind.Object
            && message.TryGetProperty("usage", out var msgUsage))
            ApplyUsage(msgUsage, ref inputTokens, ref outputTokens);
    }

    private static void ApplyUsage(JsonElement usage, ref int inputTokens, ref int outputTokens)
    {
        if (usage.ValueKind != JsonValueKind.Object) return;

        // TryGetInt32 statt GetInt32: liefert bei Dezimal/Out-of-Range false (kein Throw).
        // ValueKind-Guard bleibt, weil TryGetInt32 bei Nicht-Number (String/Bool/...) WIRFT.
        if (usage.TryGetProperty("input_tokens", out var inp)
            && inp.ValueKind == JsonValueKind.Number
            && inp.TryGetInt32(out var inpVal))
            inputTokens = Math.Max(inputTokens, inpVal);

        if (usage.TryGetProperty("output_tokens", out var outp)
            && outp.ValueKind == JsonValueKind.Number
            && outp.TryGetInt32(out var outpVal))
            outputTokens = Math.Max(outputTokens, outpVal);
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
            return JsonSerializer.Deserialize(
                File.ReadAllText(path),
                SwitchboardJsonContext.Default.DictionaryStringModelUsage) ?? [];
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
            JsonSerializer.Serialize(data, SwitchboardJsonContext.Default.DictionaryStringModelUsage));
        File.Move(tmp, path, overwrite: true);
    }
}

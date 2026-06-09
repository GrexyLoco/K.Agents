namespace K.Switchboard.Resources;

/// <summary>
/// Read-only Telemetrie-Store: aggregiert Live-Messungen pro Modell in <c>learned-stats.json</c>
/// (Per-Install, ApplicationData, NICHT committed). Beeinflusst die Admission NICHT. Siehe Spec §3.
/// </summary>
public sealed class LocalStatsStore : ILocalStatsStore
{
    private readonly string _filePath;
    private readonly ILogger<LocalStatsStore> _logger;
    private readonly SemaphoreSlim _lock = new(1, 1);
    private Dictionary<string, LocalInferenceStats>? _cache;

    /// <summary>Produktiver ctor: %APPDATA%/K.Switchboard.</summary>
    public LocalStatsStore(ILogger<LocalStatsStore> logger)
        : this(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "K.Switchboard"), logger)
    { }

    /// <summary>Test-ctor mit explizitem Verzeichnis.</summary>
    public LocalStatsStore(string directory, ILogger<LocalStatsStore> logger)
    {
        Directory.CreateDirectory(directory);
        _filePath = Path.Combine(directory, "learned-stats.json");
        _logger = logger;
    }

    public LocalInferenceStats? Get(string model)
    {
        _lock.Wait();
        try
        {
            return Load().TryGetValue(model, out var s) ? s : null;
        }
        finally { _lock.Release(); }
    }

    public void Record(string model, long elapsedMs, int ramDeltaMb, int sizeMb)
    {
        _lock.Wait();
        try
        {
            var map = Load();
            map.TryGetValue(model, out var prev);
            var count = (prev?.Count ?? 0) + 1;
            var avg = prev is null ? elapsedMs : (prev.AvgLatencyMs * prev.Count + elapsedMs) / count;
            map[model] = new LocalInferenceStats
            {
                Count = count,
                LastLatencyMs = elapsedMs,
                AvgLatencyMs = avg,
                MaxLatencyMs = Math.Max(prev?.MaxLatencyMs ?? 0, elapsedMs),
                LastRamDeltaMb = ramDeltaMb,
                LastSizeMb = sizeMb,
                UpdatedOn = DateTimeOffset.UtcNow
            };
            Save(map);
            _logger.LogInformation(
                "Live-Telemetrie {Model}: {Ms}ms, ramΔ {Ram}MB, size {Size}MB (n={Count})",
                model, elapsedMs, ramDeltaMb, sizeMb, count);
        }
        finally { _lock.Release(); }
    }

    private Dictionary<string, LocalInferenceStats> Load()
    {
        if (_cache is not null) return _cache;
        try
        {
            _cache = File.Exists(_filePath)
                ? JsonSerializer.Deserialize(File.ReadAllText(_filePath), SwitchboardJsonContext.Default.DictionaryStringLocalInferenceStats) ?? new()
                : new();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "learned-stats.json unlesbar — starte mit leerem Store.");
            _cache = new();
        }
        return _cache;
    }

    private void Save(Dictionary<string, LocalInferenceStats> map)
    {
        try
        {
            File.WriteAllText(_filePath, JsonSerializer.Serialize(map, SwitchboardJsonContext.Default.DictionaryStringLocalInferenceStats));
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "learned-stats.json konnte nicht geschrieben werden ({Path}).", _filePath);
        }
    }
}

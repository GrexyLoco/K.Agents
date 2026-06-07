namespace K.Switchboard.Resources;

/// <summary>
/// Hält das erkannte HW-Profil (a) als <c>hw-profile.json</c> im Per-Install-Verzeichnis
/// (ApplicationData, NICHT committed). Refresh bei leer/unlesbar ODER wenn der zuletzt erkannte
/// Monat (UTC) nicht der aktuelle ist (1×/Monat). Siehe Spec §3.2.
/// </summary>
public sealed class HardwareProfileCache
{
    private readonly IHardwareProfileDetector _detector;
    private readonly string _filePath;
    private readonly ILogger<HardwareProfileCache> _logger;
    private readonly SemaphoreSlim _lock = new(1, 1);
    private HardwareProfile? _memo;

    /// <summary>Produktiver ctor: nutzt %APPDATA%/K.Switchboard (cross-platform ApplicationData).</summary>
    public HardwareProfileCache(IHardwareProfileDetector detector, ILogger<HardwareProfileCache> logger)
        : this(detector,
               Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "K.Switchboard"),
               logger)
    { }

    /// <summary>Test-ctor mit explizitem Verzeichnis (analog CostingService).</summary>
    public HardwareProfileCache(IHardwareProfileDetector detector, string directory, ILogger<HardwareProfileCache> logger)
    {
        _detector = detector;
        Directory.CreateDirectory(directory);
        _filePath = Path.Combine(directory, "hw-profile.json");
        _logger = logger;
    }

    /// <summary>Liefert das (ggf. neu erkannte) Profil.</summary>
    public async Task<HardwareProfile> GetAsync(CancellationToken ct)
    {
        if (_memo is { } m && IsCurrentMonth(m.DetectedOn))
            return m;

        await _lock.WaitAsync(ct);
        try
        {
            // Double-Check: ein paralleler Caller könnte das Memo gesetzt haben, während wir warteten.
            if (_memo is { } cached && IsCurrentMonth(cached.DetectedOn))
                return cached;

            var loaded = TryLoad();
            if (loaded is { } p && IsCurrentMonth(p.DetectedOn))
            {
                _memo = p;
                return p;
            }

            _logger.LogInformation("HW-Profil-Cache leer/veraltet → Neu-Detektion.");
            var fresh = await _detector.DetectAsync(ct);
            await SaveAsync(fresh, ct);
            _memo = fresh;
            return fresh;
        }
        finally
        {
            _lock.Release();
        }
    }

    private static bool IsCurrentMonth(DateTimeOffset detectedOn)
    {
        var now = DateTimeOffset.UtcNow;
        return detectedOn.Year == now.Year && detectedOn.Month == now.Month;
    }

    private HardwareProfile? TryLoad()
    {
        try
        {
            if (!File.Exists(_filePath)) return null;
            var json = File.ReadAllText(_filePath);
            return JsonSerializer.Deserialize(json, SwitchboardJsonContext.Default.HardwareProfile);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "HW-Profil-Cache unlesbar — wird neu erkannt.");
            return null;
        }
    }

    private async Task SaveAsync(HardwareProfile profile, CancellationToken ct)
    {
        try
        {
            var json = JsonSerializer.Serialize(profile, SwitchboardJsonContext.Default.HardwareProfile);
            await File.WriteAllTextAsync(_filePath, json, ct);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "HW-Profil-Cache konnte nicht geschrieben werden ({Path}).", _filePath);
        }
    }
}

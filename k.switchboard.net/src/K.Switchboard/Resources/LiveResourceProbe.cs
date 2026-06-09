namespace K.Switchboard.Resources;

using System.Text.Json;

/// <summary>
/// Freier RAM via GC-MemoryInfo (trim-safe); CPU-Last via <see cref="ICpuLoadSampler"/>;
/// Warmth via Ollama <c>/api/ps</c>. Alle Reads sind billig und best-effort (Fehler ⇒ neutraler Wert).
/// </summary>
public sealed class LiveResourceProbe(
    IHttpClientFactory httpFactory,
    ICpuLoadSampler cpuSampler,
    IOptionsMonitor<SwitchboardOptions> options,
    ILogger<LiveResourceProbe> logger) : ILiveResourceProbe
{
    public async Task<LiveResourceSnapshot> SampleAsync(string model, int cpuWindowSeconds, CancellationToken ct)
    {
        var info = GC.GetGCMemoryInfo();
        var freeBytes = info.TotalAvailableMemoryBytes - info.MemoryLoadBytes;
        var freeRamMb = (int)(Math.Max(0, freeBytes) / (1024 * 1024));

        var cpu = await cpuSampler.SampleAsync(cpuWindowSeconds, ct);
        var warm = await IsWarmAsync(model, ct);

        return new LiveResourceSnapshot { FreeRamMb = freeRamMb, CpuLoadPercent = cpu, ModelWarm = warm };
    }

    private async Task<bool> IsWarmAsync(string model, CancellationToken ct)
    {
        try
        {
            var client = httpFactory.CreateClient("ollama");
            var baseUrl = options.CurrentValue.OllamaBaseUrl.TrimEnd('/');
            // Probe-lokales Kurz-Timeout: der "ollama"-Client hat ein langes Inferenz-Timeout (600s).
            // /api/ps muss billig bleiben — bei hängendem Ollama nach 3s abbrechen → Modell = kalt.
            using var timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
            timeoutCts.CancelAfter(TimeSpan.FromSeconds(3));
            using var resp = await client.GetAsync($"{baseUrl}/api/ps", timeoutCts.Token);
            if (!resp.IsSuccessStatusCode) return false;
            var json = await resp.Content.ReadAsStringAsync(timeoutCts.Token);
            using var doc = JsonDocument.Parse(json);
            if (!doc.RootElement.TryGetProperty("models", out var models)) return false;
            foreach (var m in models.EnumerateArray())
            {
                if (m.TryGetProperty("name", out var name)
                    && string.Equals(name.GetString(), model, StringComparison.OrdinalIgnoreCase))
                    return true;
            }
            return false;
        }
        catch (Exception ex)
        {
            logger.LogDebug(ex, "Ollama /api/ps nicht erreichbar — Modell als kalt gewertet.");
            return false;
        }
    }
}

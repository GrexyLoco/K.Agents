namespace K.Switchboard.Resources;

using System.Globalization;
using System.Runtime.InteropServices;

/// <summary>
/// MVP-CPU-Last: Linux via zwei /proc/stat-Snapshots (Delta); andere Plattformen
/// liefern 0 (nicht-blockierend) — robustere Messung folgt in Ausbau +1.
/// </summary>
public sealed class CpuLoadSampler : ICpuLoadSampler
{
    public async Task<double> SampleAsync(int windowSeconds, CancellationToken ct)
    {
        if (!RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
            return 0.0;

        var sampleMs = Math.Clamp(windowSeconds, 1, 10) * 1000;
        var (idle1, total1) = ReadProcStat();
        await Task.Delay(Math.Min(sampleMs, 1000), ct);   // kurzes Fenster, max 1s Blockade
        var (idle2, total2) = ReadProcStat();

        var totalDelta = total2 - total1;
        var idleDelta = idle2 - idle1;
        if (totalDelta <= 0) return 0.0;
        return Math.Clamp(100.0 * (totalDelta - idleDelta) / totalDelta, 0, 100);
    }

    private static (long Idle, long Total) ReadProcStat()
    {
        try
        {
            var line = File.ReadLines("/proc/stat").FirstOrDefault(l => l.StartsWith("cpu ")) ?? string.Empty;
            var nums = line.Split(' ', StringSplitOptions.RemoveEmptyEntries).Skip(1)
                           .Select(s => long.TryParse(s, NumberStyles.Integer, CultureInfo.InvariantCulture, out var v) ? v : 0)
                           .ToArray();
            if (nums.Length < 5) return (0, 0);
            var idle = nums[3] + (nums.Length > 4 ? nums[4] : 0);   // idle + iowait
            var total = nums.Sum();
            return (idle, total);
        }
        catch
        {
            return (0, 0);
        }
    }
}

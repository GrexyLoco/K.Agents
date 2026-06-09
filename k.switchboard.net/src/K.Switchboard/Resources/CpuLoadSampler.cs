namespace K.Switchboard.Resources;

using System.Globalization;
using System.Runtime.InteropServices;

/// <summary>
/// System-CPU-Last (%): Linux via zwei /proc/stat-Snapshots, Windows via GetSystemTimes
/// (source-generated P/Invoke, trim-safe). macOS/andere liefern 0 (nicht unterstützt).
/// </summary>
public sealed partial class CpuLoadSampler : ICpuLoadSampler
{
    public async Task<double> SampleAsync(int windowSeconds, CancellationToken ct)
    {
        var sampleMs = Math.Min(Math.Clamp(windowSeconds, 1, 10) * 1000, 1000);

        if (RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
        {
            var (idle1, total1) = ReadProcStat();
            await Task.Delay(sampleMs, ct);
            var (idle2, total2) = ReadProcStat();
            return BusyPercent(total2 - total1, idle2 - idle1);
        }

        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            if (!TryReadWindowsTimes(out var idle1, out var total1)) return 0.0;
            await Task.Delay(sampleMs, ct);
            if (!TryReadWindowsTimes(out var idle2, out var total2)) return 0.0;
            return BusyPercent(total2 - total1, idle2 - idle1);
        }

        return 0.0;   // macOS/andere — nicht unterstützt
    }

    /// <summary>busy% aus Delta. Internal für deterministischen Unit-Test (InternalsVisibleTo).</summary>
    internal static double BusyPercent(long totalDelta, long idleDelta)
        => totalDelta <= 0 ? 0.0 : Math.Clamp(100.0 * (totalDelta - idleDelta) / totalDelta, 0, 100);

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

    private static bool TryReadWindowsTimes(out long idle, out long total)
    {
        idle = 0;
        total = 0;
        if (!GetSystemTimes(out var idleTime, out var kernelTime, out var userTime))
            return false;
        // Windows: kernelTime ENTHÄLT idleTime. total = kernel + user; busy = total − idle.
        idle = idleTime;
        total = kernelTime + userTime;
        return true;
    }

    [LibraryImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool GetSystemTimes(out long lpIdleTime, out long lpKernelTime, out long lpUserTime);
}

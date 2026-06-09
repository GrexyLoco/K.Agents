namespace K.Switchboard.Resources;

using System.Globalization;
using System.Runtime.InteropServices;

/// <summary>
/// RAM/CPU via .NET-APIs (trim-safe, keine P/Invoke); GPU/VRAM via CLI-Subprozess je OS.
/// Fehlt das GPU-Tool, wird GpuVendor="none" gesetzt (CPU-Pfad). Siehe Spec §3.1.
/// </summary>
public sealed class HardwareProfileDetector(
    IProcessRunner runner,
    ILogger<HardwareProfileDetector> logger) : IHardwareProfileDetector
{
    public async Task<HardwareProfile> DetectAsync(CancellationToken ct)
    {
        var totalRamMb = (int)(GC.GetGCMemoryInfo().TotalAvailableMemoryBytes / (1024 * 1024));
        var cores = Environment.ProcessorCount;
        var (vendor, model, vram) = await DetectGpuAsync(ct);

        var profile = new HardwareProfile
        {
            TotalRamMb = totalRamMb,
            Cores = cores,
            GpuVendor = vendor,
            GpuModel = model,
            VramMb = vram,
            DetectedOn = DateTimeOffset.UtcNow
        };
        logger.LogInformation(
            "HW-Profil erkannt: RAM={RamMb}MB Cores={Cores} GPU={Vendor}/{Model} VRAM={VramMb}MB",
            totalRamMb, cores, vendor, model, vram);
        return profile;
    }

    private async Task<(string Vendor, string Model, int VramMb)> DetectGpuAsync(CancellationToken ct)
    {
        // 1) NVIDIA via nvidia-smi (cross-platform, falls Treiber installiert)
        var (exit, output) = await runner.RunAsync(
            "nvidia-smi", "--query-gpu=name,memory.total --format=csv,noheader,nounits", ct);
        if (exit == 0 && !string.IsNullOrWhiteSpace(output))
        {
            var line = output.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                             .FirstOrDefault() ?? string.Empty;
            var parts = line.Split(',', StringSplitOptions.TrimEntries);
            if (parts.Length >= 2 && int.TryParse(parts[1], NumberStyles.Integer, CultureInfo.InvariantCulture, out var mb))
                return ("NVIDIA", parts[0], mb);
        }

        // 2) AMD via rocm-smi (Linux + Windows, falls ROCm installiert)
        var (rexit, rout) = await runner.RunAsync("rocm-smi", "--showmeminfo vram --csv", ct);
        if (rexit == 0 && !string.IsNullOrWhiteSpace(rout))
        {
            // CSV: Header + Datenzeilen; eine Spalte enthält "VRAM Total Memory (B)" in Bytes.
            var lines = rout.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
            var header = lines.FirstOrDefault()?.Split(',', StringSplitOptions.TrimEntries) ?? [];
            var vramCol = Array.FindIndex(header, h => h.Contains("VRAM Total Memory", StringComparison.OrdinalIgnoreCase));
            if (vramCol >= 0)
            {
                foreach (var dataLine in lines.Skip(1))
                {
                    var cols = dataLine.Split(',', StringSplitOptions.TrimEntries);
                    if (cols.Length > vramCol
                        && long.TryParse(cols[vramCol], NumberStyles.Integer, CultureInfo.InvariantCulture, out var bytes)
                        && bytes > 0)
                    {
                        return ("AMD", "amd-rocm-gpu", (int)(bytes / (1024 * 1024)));
                    }
                }
            }
        }

        // 3) Windows-Fallback: wmic VideoController (AdapterRAM in Bytes)
        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            var (wexit, wout) = await runner.RunAsync(
                "wmic", "path win32_VideoController get name,AdapterRAM /format:csv", ct);
            if (wexit == 0 && !string.IsNullOrWhiteSpace(wout))
            {
                var (vendor, model, vram) = ParseWmic(wout);
                if (!string.IsNullOrEmpty(model))
                    return (vendor, model, vram);
            }
        }

        // 4) macOS-Fallback: system_profiler (VRAM nicht zuverlässig parsebar → 0, CPU-Pfad)
        if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
        {
            var (mexit, mout) = await runner.RunAsync("system_profiler", "SPDisplaysDataType", ct);
            if (mexit == 0 && mout.Contains("Chipset Model", StringComparison.OrdinalIgnoreCase))
                return ("AMD", "apple-or-amd-gpu", 0);
        }

        logger.LogInformation("Keine GPU erkannt (Tool fehlt/Exit≠0) → CPU-Pfad.");
        return ("none", string.Empty, 0);
    }

    private static (string Vendor, string Model, int VramMb) ParseWmic(string csv)
    {
        // CSV-Zeilen: Node,AdapterRAM,Name — Header überspringen, erste Datenzeile nutzen.
        foreach (var raw in csv.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            if (raw.StartsWith("Node", StringComparison.OrdinalIgnoreCase)) continue;
            var cols = raw.Split(',', StringSplitOptions.TrimEntries);
            if (cols.Length < 3) continue;
            var name = cols[2];
            _ = long.TryParse(cols[1], out var bytes);
            var vendor = name.Contains("NVIDIA", StringComparison.OrdinalIgnoreCase) ? "NVIDIA"
                       : name.Contains("AMD", StringComparison.OrdinalIgnoreCase)
                         || name.Contains("Radeon", StringComparison.OrdinalIgnoreCase) ? "AMD" : "none";
            return (vendor, name, (int)(bytes / (1024 * 1024)));
        }
        return ("none", string.Empty, 0);
    }
}

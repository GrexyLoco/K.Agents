namespace K.Switchboard.Resources;

/// <summary>
/// Ordnet ein erkanntes <see cref="HardwareProfile"/> der ersten passenden
/// <see cref="HardwareClassConfig"/> zu. Null-Match-Felder = kein Constraint. Siehe Spec §4.1.
/// </summary>
public sealed class HardwareClassifier
{
    /// <summary>Erste passende Klasse oder null (kein Match).</summary>
    public HardwareClassConfig? Match(HardwareProfile profile, IReadOnlyList<HardwareClassConfig> classes)
    {
        foreach (var c in classes)
        {
            if (Matches(profile, c.Match))
                return c;
        }
        return null;
    }

    private static bool Matches(HardwareProfile p, HardwareClassMatch m)
    {
        if (m.MinRamMb is { } minRam && p.TotalRamMb < minRam) return false;
        if (m.MaxRamMb is { } maxRam && p.TotalRamMb > maxRam) return false;
        if (m.MinCores is { } minCores && p.Cores < minCores) return false;
        if (m.GpuVendor is { } vendor && !string.Equals(vendor, p.GpuVendor, StringComparison.OrdinalIgnoreCase)) return false;
        if (m.MinVramMb is { } minVram && p.VramMb < minVram) return false;
        if (m.MaxVramMb is { } maxVram && p.VramMb > maxVram) return false;
        return true;
    }
}

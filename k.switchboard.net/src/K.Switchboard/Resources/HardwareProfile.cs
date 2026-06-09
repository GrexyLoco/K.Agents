namespace K.Switchboard.Resources;

/// <summary>
/// Erkanntes Maschinen-Profil (a) — maschinenspezifisch, im Per-Install-Cache gehalten,
/// NICHT committed. Siehe Spec §3.2.
/// </summary>
public sealed record HardwareProfile
{
    /// <summary>Gesamter System-RAM in MB.</summary>
    public int TotalRamMb { get; init; }

    /// <summary>Logische CPU-Kerne.</summary>
    public int Cores { get; init; }

    /// <summary>GPU-Vendor: "NVIDIA", "AMD" oder "none".</summary>
    public string GpuVendor { get; init; } = "none";

    /// <summary>GPU-Modellname (oder leer).</summary>
    public string GpuModel { get; init; } = string.Empty;

    /// <summary>VRAM in MB (0 = keine/unbekannte GPU).</summary>
    public int VramMb { get; init; }

    /// <summary>UTC-Zeitpunkt der Erkennung (für monatlichen Refresh).</summary>
    public DateTimeOffset DetectedOn { get; init; }
}

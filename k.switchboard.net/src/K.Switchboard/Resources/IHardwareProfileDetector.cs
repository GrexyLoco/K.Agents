namespace K.Switchboard.Resources;

/// <summary>Erkennt das statische HW-Profil (a) der aktuellen Maschine.</summary>
public interface IHardwareProfileDetector
{
    /// <summary>Erkennt RAM/CPU (.NET-APIs) + GPU/VRAM (Subprozess). DetectedOn = jetzt (UTC).</summary>
    Task<HardwareProfile> DetectAsync(CancellationToken ct);
}

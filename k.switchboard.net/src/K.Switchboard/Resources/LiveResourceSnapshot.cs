namespace K.Switchboard.Resources;

/// <summary>Billige Live-Messung pro Request (Spec §3.3).</summary>
public sealed record LiveResourceSnapshot
{
    /// <summary>Aktuell freier System-RAM in MB.</summary>
    public int FreeRamMb { get; init; }

    /// <summary>CPU-Last in Prozent (rollender Mittelwert).</summary>
    public double CpuLoadPercent { get; init; }

    /// <summary>Ist das Zielmodell bereits in Ollama geladen (warm)?</summary>
    public bool ModelWarm { get; init; }
}

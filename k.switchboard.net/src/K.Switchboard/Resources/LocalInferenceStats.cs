namespace K.Switchboard.Resources;

/// <summary>Aggregierte Live-Telemetrie eines lokalen Modells (read-only Beobachtung). Siehe Spec §3.</summary>
public sealed record LocalInferenceStats
{
    /// <summary>Anzahl erfasster Inferenzen.</summary>
    public int Count { get; init; }

    /// <summary>Letzte gemessene End-to-End-Latenz (ms).</summary>
    public long LastLatencyMs { get; init; }

    /// <summary>Laufender Mittelwert der Latenz (ms).</summary>
    public double AvgLatencyMs { get; init; }

    /// <summary>Maximale gemessene Latenz (ms).</summary>
    public long MaxLatencyMs { get; init; }

    /// <summary>Letztes RAM-Delta (MB, 2-Punkt-GC-Approximation).</summary>
    public int LastRamDeltaMb { get; init; }

    /// <summary>Zuletzt gemeldete Modellgröße (MB) oder 0.</summary>
    public int LastSizeMb { get; init; }

    /// <summary>UTC-Zeitpunkt der letzten Aktualisierung.</summary>
    public DateTimeOffset UpdatedOn { get; init; }
}

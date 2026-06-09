namespace K.Switchboard.Resources;

/// <summary>Persistiert read-only Live-Telemetrie pro lokalem Modell (learned-stats.json).</summary>
public interface ILocalStatsStore
{
    /// <summary>Erfasst eine Inferenz-Messung und aktualisiert die Aggregation.</summary>
    void Record(string model, long elapsedMs, int ramDeltaMb, int sizeMb);

    /// <summary>Aktuelle Aggregation eines Modells oder null.</summary>
    LocalInferenceStats? Get(string model);
}

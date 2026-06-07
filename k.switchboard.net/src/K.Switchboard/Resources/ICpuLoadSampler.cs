namespace K.Switchboard.Resources;

/// <summary>Liefert die System-CPU-Last (%) als rollenden Mittelwert über ein kurzes Fenster.</summary>
public interface ICpuLoadSampler
{
    /// <summary>Mittlere CPU-Last (0–100) über <paramref name="windowSeconds"/>.</summary>
    Task<double> SampleAsync(int windowSeconds, CancellationToken ct);
}

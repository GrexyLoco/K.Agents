namespace K.Switchboard.Resources;

/// <summary>Billige Live-Ressourcen-Messung pro Request.</summary>
public interface ILiveResourceProbe
{
    /// <summary>Misst freien RAM, CPU-Last und ob <paramref name="model"/> in Ollama warm ist.</summary>
    Task<LiveResourceSnapshot> SampleAsync(string model, int cpuWindowSeconds, CancellationToken ct);
}

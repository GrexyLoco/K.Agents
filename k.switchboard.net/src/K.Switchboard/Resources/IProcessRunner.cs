namespace K.Switchboard.Resources;

/// <summary>Dünne, testbare Abstraktion für CLI-Subprozesse (GPU-Detektion).</summary>
public interface IProcessRunner
{
    /// <summary>Führt <paramref name="file"/> mit <paramref name="args"/> aus.
    /// Liefert Exit-Code + stdout. Wirft NICHT bei Nicht-Null-Exit; Fehler = (Exit≠0).</summary>
    Task<(int ExitCode, string StdOut)> RunAsync(string file, string args, CancellationToken ct);
}

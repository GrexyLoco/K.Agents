namespace K.Switchboard.Resources;

using System.Diagnostics;

/// <summary>Produktive <see cref="IProcessRunner"/>-Implementierung. Schluckt fehlende Binaries.</summary>
public sealed class ProcessRunner : IProcessRunner
{
    public async Task<(int ExitCode, string StdOut)> RunAsync(string file, string args, CancellationToken ct)
    {
        try
        {
            using var proc = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = file,
                    Arguments = args,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true
                }
            };
            if (!proc.Start())
                return (1, string.Empty);

            var stdout = await proc.StandardOutput.ReadToEndAsync(ct);
            await proc.WaitForExitAsync(ct);
            return (proc.ExitCode, stdout);
        }
        catch (Exception)   // Binary nicht im PATH / Plattform ohne Tool → kein harter Fehler
        {
            return (1, string.Empty);
        }
    }
}

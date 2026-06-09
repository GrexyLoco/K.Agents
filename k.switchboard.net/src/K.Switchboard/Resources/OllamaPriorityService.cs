namespace K.Switchboard.Resources;

using System.Runtime.InteropServices;
using Microsoft.Extensions.Hosting;

/// <summary>
/// Senkt beim Start die Priorität des lokalen Ollama-Prozesses auf below-normal (Maschinen-Schutz),
/// wenn <see cref="ResourceGateOptions.LowerOllamaPriority"/> aktiv ist und Ollama lokal läuft.
/// Best-effort, einmalig beim Start. macOS nicht unterstützt. Siehe Spec §2.
/// </summary>
public sealed class OllamaPriorityService(
    IProcessController processController,
    IOptionsMonitor<SwitchboardOptions> options,
    ILogger<OllamaPriorityService> logger) : IHostedService
{
    public Task StartAsync(CancellationToken cancellationToken)
    {
        ApplyOnce();
        return Task.CompletedTask;
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;

    /// <summary>Kern-Logik (testbar): Priorität einmalig anwenden, sofern Vorbedingungen erfüllt.</summary>
    public void ApplyOnce()
    {
        var opts = options.CurrentValue;
        if (!opts.ResourceGate.LowerOllamaPriority)
            return;

        if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
        {
            logger.LogInformation("Ollama-Priorität: macOS nicht unterstützt — übersprungen.");
            return;
        }

        if (!IsLocalHost(opts.OllamaBaseUrl))
        {
            logger.LogInformation(
                "Ollama-Priorität: OllamaBaseUrl '{Url}' ist nicht localhost — Priorität nicht beeinflussbar.",
                opts.OllamaBaseUrl);
            return;
        }

        var pids = processController.FindByName("ollama");
        if (pids.Count == 0)
        {
            logger.LogWarning("Ollama-Priorität: kein 'ollama'-Prozess gefunden.");
            return;
        }

        foreach (var pid in pids)
        {
            if (processController.TrySetBelowNormal(pid))
                logger.LogInformation("Ollama-Priorität: PID {Pid} auf below-normal gesetzt.", pid);
            else
                logger.LogWarning("Ollama-Priorität: PID {Pid} konnte nicht gesetzt werden (Rechte?).", pid);
        }
    }

    /// <summary>True, wenn die URL auf localhost zeigt (localhost/127.0.0.1/::1). Auch von der
    /// Telemetrie im <see cref="K.Switchboard.Providers.OllamaProvider"/> genutzt.</summary>
    internal static bool IsLocalHost(string baseUrl)
    {
        if (!Uri.TryCreate(baseUrl, UriKind.Absolute, out var uri))
            return false;
        var host = uri.Host;
        return host.Equals("localhost", StringComparison.OrdinalIgnoreCase)
            || host == "127.0.0.1"
            || host == "::1"
            || host == "[::1]";
    }
}

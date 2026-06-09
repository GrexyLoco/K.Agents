namespace K.Switchboard.Resources;

using K.Switchboard.Routing;

/// <summary>
/// Pre-flight-Gate VOR dem FallbackService (Spec §2). Prüft nur das primär angefragte Modell:
/// lokal ausführbar → Proceed; sonst Defer-to-Fallback / Tier-Substitution / Fail.
/// </summary>
public sealed class ResourceGate(
    ModelRouter router,
    HardwareProfileCache cache,
    HardwareClassifier classifier,
    ILiveResourceProbe probe,
    IOptionsMonitor<SwitchboardOptions> options,
    ILogger<ResourceGate> logger)
{
    public async Task<RoutingDecision> EvaluateAsync(string requestedModel, int inputTokens, CancellationToken ct)
    {
        var opts = options.CurrentValue;
        if (!opts.ResourceGate.Enabled)
            return Proceed(requestedModel, "gate-disabled");

        var (providerName, resolvedModel) = router.Resolve(requestedModel);
        if (!string.Equals(providerName, "ollama", StringComparison.OrdinalIgnoreCase))
            return Proceed(requestedModel, "non-local-provider");

        try
        {
            var profile = await cache.GetAsync(ct);
            var hwClass = classifier.Match(profile, opts.HardwareClasses);
            var validation = hwClass is not null && hwClass.Models.TryGetValue(resolvedModel, out var v) ? v : null;

            if (validation is null)
                return BuildSubstitution(requestedModel, resolvedModel, opts,
                    hwClass is null ? "no matching hardware class" : "no validated footprint");

            var gpuPath = validation.PeakVramMb > 0
                          && !string.Equals(profile.GpuVendor, "none", StringComparison.OrdinalIgnoreCase)
                          && profile.VramMb > 0;

            if (!gpuPath && validation.PeakRamMb <= 0)
                return BuildSubstitution(requestedModel, resolvedModel, opts, "no validated footprint");

            var live = await probe.SampleAsync(resolvedModel, opts.ResourceGate.CpuLoadWindowSeconds, ct);

            if (live.CpuLoadPercent > opts.ResourceGate.CpuMaxLoadPercent)
                return BuildSubstitution(requestedModel, resolvedModel, opts, $"CPU {live.CpuLoadPercent:F0}%");

            if (gpuPath)
            {
                // Math.Max(0, …): bei Fehlkonfiguration (Reserve > VRAM) nicht negativ werden (klare Meldung statt "-512MB").
                var usableVram = Math.Max(0, profile.VramMb - opts.ResourceGate.VramDisplayReserveMb);
                if (validation.PeakVramMb > usableVram)
                    return BuildSubstitution(requestedModel, resolvedModel, opts,
                        $"VRAM {validation.PeakVramMb}MB/{usableVram}MB");
            }
            else
            {
                var buffer = opts.ResourceGate.RamBufferMb > 0
                    ? opts.ResourceGate.RamBufferMb
                    : Math.Max(1024, validation.PeakRamMb / 4);
                var need = validation.PeakRamMb + buffer;
                if (live.FreeRamMb < need)
                    return BuildSubstitution(requestedModel, resolvedModel, opts, $"free {live.FreeRamMb}MB/{need}MB");
            }

            if (LatencyExceeded(validation, live, opts.ResourceGate, inputTokens, out var latReason))
                return BuildSubstitution(requestedModel, resolvedModel, opts, latReason);

            logger.LogInformation(
                "ResourceGate: lokal zugelassen {Model} ({Path}, CPU {Cpu}%, warm={Warm})",
                resolvedModel, gpuPath ? "GPU" : "CPU", live.CpuLoadPercent, live.ModelWarm);
            return Proceed(requestedModel, $"local-admitted {(gpuPath ? "gpu" : "cpu")} warm={live.ModelWarm}");
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            logger.LogWarning(ex,
                "ResourceGate: Ressourcen-Check fehlgeschlagen für {Model} → fail-open (Proceed).", requestedModel);
            return Proceed(requestedModel, "resource-monitor-error");
        }
    }

    private RoutingDecision BuildSubstitution(string requestedModel, string localModel, SwitchboardOptions opts, string reason)
    {
        // 1) Explizite Fallback-Kette hat Vorrang (Nutzer-konfiguriert).
        if (opts.FallbackChains.TryGetValue(requestedModel, out var chain) && chain.Count > 0)
        {
            var target = chain[0];
            var header = $"{localModel} -> {target} (deferred: {reason})";
            logger.LogInformation("ResourceGate: defer-to-fallback {Header}", header);
            return new RoutingDecision { Action = RoutingAction.Proceed, EffectiveModel = target, Reason = reason, SubstitutionHeader = header };
        }

        // 2) Tier-Substitution.
        if (opts.LocalModelTiers.TryGetValue(localModel, out var tier))
        {
            if (opts.TierSubstitutions.TryGetValue(tier, out var claude))
            {
                var header = $"{claude} (local {localModel} not viable — {reason})";
                logger.LogInformation("ResourceGate: substitution {Header}", header);
                return new RoutingDecision { Action = RoutingAction.Proceed, EffectiveModel = claude, Reason = reason, SubstitutionHeader = header };
            }

            // Tier konfiguriert, aber kein Substitut hinterlegt → klaren Grund loggen (sonst opakes 503).
            logger.LogWarning(
                "ResourceGate: Tier '{Tier}' für {Model} ist nicht in TierSubstitutions konfiguriert.", tier, localModel);
        }

        // 3) Kein Fallback, kein Substitut → hart fehlschlagen.
        logger.LogWarning("ResourceGate: kein Fallback/Substitut für {Model} ({Reason}) → 503", localModel, reason);
        return new RoutingDecision { Action = RoutingAction.Fail, Reason = reason, FailStatusCode = StatusCodes.Status503ServiceUnavailable };
    }

    private static bool LatencyExceeded(ModelValidation validation, LiveResourceSnapshot live, ResourceGateOptions gate, int inputTokens, out string reason)
    {
        reason = string.Empty;
        if (gate.MaxLatencyMs <= 0 || validation.LatencyP50Ms <= 0)
            return false;   // Gate aus oder keine Latenz-Daten → nicht blockieren

        var contextFactor = Math.Max(0.5, (double)inputTokens / Math.Max(1, gate.LatencyContextReferenceTokens));
        var coldFactor = live.ModelWarm ? 1.0 : gate.ColdLatencyFactor;
        var expectedMs = validation.LatencyP50Ms * coldFactor * contextFactor;
        if (expectedMs > gate.MaxLatencyMs)
        {
            reason = $"latency ~{expectedMs:F0}ms > {gate.MaxLatencyMs}ms (warm={live.ModelWarm}, ctx×{contextFactor:F1})";
            return true;
        }
        return false;
    }

    private static RoutingDecision Proceed(string model, string reason)
        => new() { Action = RoutingAction.Proceed, EffectiveModel = model, Reason = reason };
}

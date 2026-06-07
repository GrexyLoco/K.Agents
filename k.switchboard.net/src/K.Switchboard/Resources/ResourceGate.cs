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
    public async Task<RoutingDecision> EvaluateAsync(string requestedModel, CancellationToken ct)
    {
        var opts = options.CurrentValue;
        if (!opts.ResourceGate.Enabled)
            return Proceed(requestedModel, "gate-disabled");

        var (providerName, resolvedModel) = router.Resolve(requestedModel);
        if (!string.Equals(providerName, "ollama", StringComparison.OrdinalIgnoreCase))
            return Proceed(requestedModel, "non-local-provider");

        var profile = await cache.GetAsync(ct);
        var hwClass = classifier.Match(profile, opts.HardwareClasses);
        var validation = hwClass is not null && hwClass.Models.TryGetValue(resolvedModel, out var v) ? v : null;

        if (validation is { PeakRamMb: > 0 })
        {
            var buffer = opts.ResourceGate.RamBufferMb > 0
                ? opts.ResourceGate.RamBufferMb
                : Math.Max(1024, validation.PeakRamMb / 4);
            var need = validation.PeakRamMb + buffer;
            var live = await probe.SampleAsync(resolvedModel, opts.ResourceGate.CpuLoadWindowSeconds, ct);

            if (live.FreeRamMb >= need && live.CpuLoadPercent <= opts.ResourceGate.CpuMaxLoadPercent)
            {
                logger.LogInformation(
                    "ResourceGate: lokal zugelassen {Model} (frei {Free}MB ≥ {Need}MB, CPU {Cpu}%, warm={Warm})",
                    resolvedModel, live.FreeRamMb, need, live.CpuLoadPercent, live.ModelWarm);
                return Proceed(requestedModel, $"local-admitted free={live.FreeRamMb}MB warm={live.ModelWarm}");
            }

            return BuildSubstitution(requestedModel, resolvedModel, opts,
                $"free {live.FreeRamMb}MB/{need}MB, CPU {live.CpuLoadPercent:F0}%");
        }

        return BuildSubstitution(requestedModel, resolvedModel, opts,
            hwClass is null ? "no matching hardware class" : "no validated footprint");
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
        if (opts.LocalModelTiers.TryGetValue(localModel, out var tier)
            && opts.TierSubstitutions.TryGetValue(tier, out var claude))
        {
            var header = $"{claude} (local {localModel} not viable — {reason})";
            logger.LogInformation("ResourceGate: substitution {Header}", header);
            return new RoutingDecision { Action = RoutingAction.Proceed, EffectiveModel = claude, Reason = reason, SubstitutionHeader = header };
        }

        // 3) Kein Fallback, kein Substitut → hart fehlschlagen.
        logger.LogWarning("ResourceGate: kein Fallback/Substitut für {Model} ({Reason}) → 503", localModel, reason);
        return new RoutingDecision { Action = RoutingAction.Fail, Reason = reason, FailStatusCode = StatusCodes.Status503ServiceUnavailable };
    }

    private static RoutingDecision Proceed(string model, string reason)
        => new() { Action = RoutingAction.Proceed, EffectiveModel = model, Reason = reason };
}

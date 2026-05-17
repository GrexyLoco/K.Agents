namespace K.Switchboard.Services;

using Microsoft.AspNetCore.Mvc;

/// <summary>
/// Leitet Requests mit automatischem Fallback bei Provider-Fehlern weiter.
/// </summary>
/// <remarks>
/// Fallback-Kette: primäres Modell → FallbackChains[requestedModel][0] → [1] → …
/// Bei Erfolg eines Fallbacks wird der Header <c>X-K-Switchboard-Fallback-Used</c> gesetzt.
/// Token-Nutzung wird nach erfolgreichem Request via <see cref="CostingService"/> erfasst.
/// </remarks>
public sealed class FallbackService(
    ModelRouter router,
    ProviderRegistry registry,
    IOptionsMonitor<SwitchboardOptions> options,
    CostingService costing,
    ILogger<FallbackService> logger)
{
    /// <summary>
    /// Versucht den Request weiterzuleiten. Fällt bei HTTP 4xx/5xx oder Netzwerkfehler
    /// auf die nächste Option aus <see cref="SwitchboardOptions.FallbackChains"/> zurück.
    /// </summary>
    /// <param name="context">HTTP-Kontext — request body muss seekbar sein (EnableBuffering).</param>
    /// <param name="requestedModel">Ursprünglich angeforderter Modellname (vor Alias-Auflösung).</param>
    /// <param name="cancellationToken">Abbruch-Token.</param>
    public async Task ForwardWithFallbackAsync(
        HttpContext context,
        string requestedModel,
        CancellationToken cancellationToken)
    {
        var chain = BuildChain(requestedModel, options.CurrentValue);
        var originalBody = context.Response.Body;
        string? primaryResolvedModel = null;
        string? winnerModel = null;
        byte[]? lastCapture = null;
        byte[]? lastFailureBody = null;
        var lastFailureStatus = StatusCodes.Status502BadGateway;

        for (var i = 0; i < chain.Count; i++)
        {
            var candidate = chain[i];
            var (providerName, resolvedModel) = router.Resolve(candidate);
            if (i == 0) primaryResolvedModel = resolvedModel;

            var provider = registry.Get(providerName);
            if (provider is null)
            {
                context.Response.StatusCode = StatusCodes.Status500InternalServerError;
                context.Response.Body = originalBody;

                logger.LogError(
                    "Unbekannter Provider '{Provider}' für Modell '{Model}'. Verfügbare Provider-Konfiguration prüfen.",
                    providerName, candidate);

                await context.Response.WriteAsJsonAsync(new ProblemDetails
                {
                    Title = "Provider misconfiguration",
                    Detail = $"No registered provider for '{providerName}'."
                }, cancellationToken: cancellationToken);
                return;
            }

            // Request-Body für jeden Versuch zurücksetzen (EnableBuffering macht Stream seekbar)
            context.Request.Body.Position = 0;

            // Response in Puffer schreiben, damit bei Fehler ein Retry möglich ist
            using var capture = new MemoryStream();
            context.Response.Body = capture;

            if (i > 0)
            {
                // Fehlgeschlagene Response-State aus dem vorherigen Versuch zurücksetzen
                context.Response.Headers.Clear();
            }

            try
            {
                await provider.ForwardAsync(context, resolvedModel, cancellationToken);
            }
            catch (JsonException ex)
            {
                context.Response.StatusCode = StatusCodes.Status400BadRequest;
                context.Response.Headers.Clear();
                context.Response.Body = originalBody;

                logger.LogWarning(ex,
                    "Ungültiges Request-JSON für Provider '{Provider}' und Modell '{Model}'",
                    providerName, candidate);

                await context.Response.WriteAsJsonAsync(new ProblemDetails
                {
                    Title = "Invalid JSON payload",
                    Detail = "Request body contains invalid JSON."
                }, cancellationToken: cancellationToken);
                return;
            }
            catch (Exception ex)
            {
                context.Response.Body = originalBody;
                logger.LogWarning(ex,
                    "Provider '{Provider}' für Modell '{Model}' schlug mit Netzwerkfehler fehl",
                    providerName, candidate);
                lastCapture = null;
                continue;
            }
            finally
            {
                context.Response.Body = originalBody;
            }

            lastCapture = capture.ToArray();

            if (context.Response.StatusCode < 400)
            {
                winnerModel = resolvedModel;
                if (i > 0)
                {
                    var header = $"{primaryResolvedModel} -> {resolvedModel}";
                    context.Response.Headers["X-K-Switchboard-Fallback-Used"] = header;
                    logger.LogInformation("Fallback verwendet: {Header}", header);
                }
                break;
            }

            logger.LogWarning(
                "Modell '{Model}' lieferte HTTP {Status} — {Remaining} Fallback(s) verbleiben",
                candidate, context.Response.StatusCode, chain.Count - i - 1);

            lastFailureStatus = context.Response.StatusCode;
            lastFailureBody = lastCapture;
        }

        if (winnerModel is null)
        {
            context.Response.StatusCode = lastFailureStatus;
            if (lastFailureBody is { Length: > 0 })
                await originalBody.WriteAsync(lastFailureBody, cancellationToken);
            return;
        }

        if (lastCapture is { Length: > 0 })
            await originalBody.WriteAsync(lastCapture, cancellationToken);

        // Token-Nutzung fire-and-forget (kein Warten auf Datei-I/O)
        if (winnerModel is not null && lastCapture is { Length: > 0 })
            _ = Task.Run(() => costing.RecordUsageAsync(winnerModel, lastCapture), CancellationToken.None);
    }

    private List<string> BuildChain(string requestedModel, SwitchboardOptions opts)
    {
        var chain = new List<string> { requestedModel };

        if (!opts.FallbackChains.TryGetValue(requestedModel, out var fallbacks) || fallbacks.Count == 0)
            return chain;

        var maxFallbacks = Math.Max(0, opts.FallbackMaxDepth);
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { requestedModel };

        foreach (var fallback in fallbacks)
        {
            if (chain.Count - 1 >= maxFallbacks)
            {
                logger.LogWarning(
                    "Fallback-Kette für '{Model}' auf max. {MaxDepth} Einträge begrenzt",
                    requestedModel, maxFallbacks);
                break;
            }

            if (string.IsNullOrWhiteSpace(fallback))
            {
                logger.LogWarning("Leerer Fallback-Eintrag für '{Model}' ignoriert", requestedModel);
                continue;
            }

            if (!seen.Add(fallback))
            {
                logger.LogWarning(
                    "Duplizierter oder zyklischer Fallback '{Fallback}' für '{Model}' ignoriert",
                    fallback, requestedModel);
                continue;
            }

            chain.Add(fallback);
        }

        return chain;
    }
}

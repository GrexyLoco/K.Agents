# Code-Review-Input 03 — code-reviewer

**Aufgabe:** Reviewe den folgenden Code-Ausschnitt. Nenne konkrete Findings mit Severity (Blocker/Wichtig/Verbesserung/Hinweis), Datei:Zeile, Problem und Empfehlung. Auf Deutsch.
**Datei:** `k.switchboard.net/src/K.Switchboard/Services/CostingService.cs` (Zeilen 92–148) — *Cost-Berechnung + Datei-IO*

```csharp
            if (baselineModel is not null)
                stats.BaselineModel = baselineModel;

            await SaveStatsAsync(path, data);
        }
        catch (Exception ex)
        {
            logger.LogError(ex,
                "Nutzungsdaten konnten nicht gespeichert werden (Modell: {Model})", model);
        }
        finally
        {
            _lock.Release();
        }

        logger.LogDebug(
            "Nutzung erfasst: Modell={Model}, Input={Input}, Output={Output}, Kosten={Cost:F6} USD, "
            + "Ersparnis≈{Saved:F6} USD (Baseline={Baseline})",
            model, inputTokens, outputTokens, cost, saved, baselineModel ?? "-");
    }

    /// <summary>Gibt die aggregierten Tages-Statistiken des aktuellen UTC-Tages zurück.</summary>
    public DailyStats GetDailyStats()
    {
        var data = LoadStats(GetCostsFilePath(BaseDirectory));
        var total = data.Values.Aggregate(0m, (sum, s) => sum + s.CostUsd);
        var totalSaved = data.Values.Aggregate(0m, (sum, s) => sum + s.SavedUsd);
        return new DailyStats(
            Date: DateOnly.FromDateTime(DateTime.UtcNow),
            Models: data,
            TotalCostUsd: Math.Round(total, 6),
            TotalSavedUsd: Math.Round(totalSaved, 6));
    }

    internal decimal CalculateCost(string model, int inputTokens, int outputTokens)
    {
        if (!options.CurrentValue.Pricing.TryGetValue(model, out var pricing))
            return 0m;
        return inputTokens * pricing.InputPerMillion / 1_000_000m
             + outputTokens * pricing.OutputPerMillion / 1_000_000m;
    }

    /// <summary>
    /// Extrahiert Token-Nutzung sowohl aus einer NICHT-gestreamten Einzel-JSON-Response
    /// (Top-Level <c>usage</c>) als auch aus einem Anthropic-/Ollama-SSE-Eventstrom
    /// (<c>data: {...}</c>-Zeilen).
    /// </summary>
    /// <remarks>
    /// SSE-Akkumulation per MAXIMUM je Feld über ALLE <c>usage</c>-Vorkommen (Top-Level und
    /// unter <c>message</c>): Anthropic-<c>output_tokens</c> ist kumulativ-monoton (max=final),
    /// Anthropic-<c>input_tokens</c> steht im <c>message_start</c>, Ollama liefert die echten
    /// Werte erst im finalen <c>message_delta</c> (max ignoriert die 0 aus dem Start).
    /// Nutzt nur <see cref="JsonDocument"/> (kein Reflection-Serializer) — trim-/AOT-sicher.
    /// </remarks>
    internal static bool TryExtractUsage(byte[] body, out int inputTokens, out int outputTokens)
    {
        inputTokens = 0;
```

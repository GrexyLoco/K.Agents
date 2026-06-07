namespace K.Switchboard;

/// <summary>
/// Behebt die ASP.NET-IConfiguration-Schwäche, dass Dictionary-Keys mit ':' (Ollama-Modellnamen
/// wie "qwen2.5-coder:14b") beim Binden verloren gehen (':' = Sektions-Trenner). Liest die
/// config.json zusätzlich direkt via source-gen STJ und ersetzt die betroffenen Collections.
/// </summary>
public static class SwitchboardOptionsColonKeyLoader
{
    /// <summary>Liest <paramref name="configFilePath"/> via STJ und überschreibt die colon-anfälligen
    /// Collections in <paramref name="target"/> (in-place-Mutation der Collection-Inhalte).
    /// Fehlt/unlesbar die Datei → no-op (die IConfiguration-Bindung bleibt unverändert).
    /// Non-empty-Guard: nur wenn eine Section in der JSON-Datei tatsächlich Einträge enthält,
    /// werden die entsprechenden Collections überschrieben — so bleiben via IConfiguration
    /// (z.B. Umgebungsvariablen) gesetzte Werte erhalten, wenn die Sektion in der JSON fehlt.
    /// Null-Guard: STJ source-gen belässt fehlende Properties auf dem Typ-Default (null),
    /// nicht auf dem Record-Initializer-Default (= []); beide Seiten werden defensiv geprüft.</summary>
    public static void ApplyFromFile(SwitchboardOptions target, string configFilePath)
    {
        SwitchboardOptions? parsed;
        try
        {
            if (!File.Exists(configFilePath)) return;
            var json = File.ReadAllText(configFilePath);
            parsed = JsonSerializer.Deserialize(json, SwitchboardJsonContext.Default.SwitchboardOptions);
        }
        catch
        {
            return;   // best-effort: kaputte Datei darf den Start nicht blockieren
        }
        if (parsed is null) return;

        if (parsed.ModelAliases is { Count: > 0 } && target.ModelAliases is not null)
            ReplaceDict(target.ModelAliases, parsed.ModelAliases);

        if (parsed.LocalModelTiers is { Count: > 0 } && target.LocalModelTiers is not null)
            ReplaceDict(target.LocalModelTiers, parsed.LocalModelTiers);

        if (parsed.TierSubstitutions is { Count: > 0 } && target.TierSubstitutions is not null)
            ReplaceDict(target.TierSubstitutions, parsed.TierSubstitutions);

        if (parsed.SavingsBaseline is { Count: > 0 } && target.SavingsBaseline is not null)
            ReplaceDict(target.SavingsBaseline, parsed.SavingsBaseline);

        if (parsed.Pricing is { Count: > 0 } && target.Pricing is not null)
            ReplaceDict(target.Pricing, parsed.Pricing);

        if (parsed.FallbackChains is { Count: > 0 } && target.FallbackChains is not null)
        {
            target.FallbackChains.Clear();
            foreach (var kv in parsed.FallbackChains) target.FallbackChains[kv.Key] = kv.Value;
        }

        if (parsed.HardwareClasses is { Count: > 0 } && target.HardwareClasses is not null)
        {
            target.HardwareClasses.Clear();
            foreach (var item in parsed.HardwareClasses) target.HardwareClasses.Add(item);
        }
    }

    private static void ReplaceDict<TValue>(IDictionary<string, TValue> target, IDictionary<string, TValue> source)
    {
        target.Clear();
        foreach (var kv in source) target[kv.Key] = kv.Value;
    }
}

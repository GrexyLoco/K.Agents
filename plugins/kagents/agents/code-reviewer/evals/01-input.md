# Code-Review-Input 01 — code-reviewer

**Aufgabe:** Reviewe den folgenden Code-Ausschnitt. Nenne konkrete Findings mit Severity (Blocker/Wichtig/Verbesserung/Hinweis), Datei:Zeile, Problem und Empfehlung. Auf Deutsch.
**Datei:** `k.switchboard.net/src/K.Switchboard/Routing/ModelRouter.cs` (Zeilen 1–35) — *Routing-Heuristik*

```csharp
namespace K.Switchboard.Routing;

/// <summary>
/// Löst Modellnamen auf (ProviderName, aufgelöster Modellname).
/// </summary>
/// <remarks>
/// Auflösungsreihenfolge:
/// <list type="number">
///   <item>Alias-Lookup in <see cref="SwitchboardOptions.ModelAliases"/></item>
///   <item>Enthält der aufgelöste Name <c>:</c> → Ollama-Direktrouting</item>
///   <item>Fallback: Anthropic</item>
/// </list>
/// </remarks>
public sealed class ModelRouter(IOptionsMonitor<SwitchboardOptions> options)
{
    /// <summary>
    /// Löst einen Modellnamen auf den zuständigen Provider und den effektiven Modellnamen auf.
    /// </summary>
    /// <param name="model">Eingehender Modellname (Alias oder direkter Name).</param>
    /// <returns>Tuple aus Provider-Name und aufgelöstem Modellnamen.</returns>
    public (string ProviderName, string ResolvedModel) Resolve(string model)
    {
        var opts = options.CurrentValue;

        // 1. Alias-Lookup — Ergebnis wird durch ':'-Heuristik weiterverarbeitet
        var resolved = opts.ModelAliases.TryGetValue(model, out var alias) ? alias : model;

        // 2. ':' im Modellnamen → Ollama-Direktrouting (z.B. "codellama:13b")
        if (resolved.Contains(':'))
            return ("ollama", resolved);

        // 3. Default: Anthropic
        return ("anthropic", resolved);
    }
}
```

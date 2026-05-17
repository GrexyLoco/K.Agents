namespace K.Switchboard.Providers;

/// <summary>Abstraction für einen LLM-Backend-Provider.</summary>
public interface IProvider
{
    /// <summary>Eindeutiger Provider-Name (z.B. "anthropic", "ollama").</summary>
    string Name { get; }

    /// <summary>
    /// Leitet den HTTP-Request an den upstream Provider weiter.
    /// </summary>
    /// <param name="context">Der aktuelle HTTP-Kontext.</param>
    /// <param name="resolvedModel">Der aufgelöste Modellname für den upstream Request.</param>
    /// <param name="cancellationToken">Abbruch-Token.</param>
    Task ForwardAsync(HttpContext context, string resolvedModel, CancellationToken cancellationToken);
}

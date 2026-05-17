namespace K.Switchboard.Providers;

/// <summary>Registry aller registrierten LLM-Provider.</summary>
public sealed class ProviderRegistry(IEnumerable<IProvider> providers)
{
    private readonly Dictionary<string, IProvider> _map =
        providers.ToDictionary(p => p.Name, StringComparer.OrdinalIgnoreCase);

    /// <summary>
    /// Gibt den Provider für den angegebenen Namen zurück, oder <see langword="null"/> wenn unbekannt.
    /// </summary>
    public IProvider? Get(string name) => _map.GetValueOrDefault(name);
}

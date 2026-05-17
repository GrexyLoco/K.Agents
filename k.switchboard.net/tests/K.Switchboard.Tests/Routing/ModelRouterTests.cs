namespace K.Switchboard.Tests.Routing;

/// <summary>Unit-Tests für den <see cref="ModelRouter"/>.</summary>
public sealed class ModelRouterTests
{
    // --- Hilfsmethoden ---

    private static ModelRouter CreateRouter(SwitchboardOptions? opts = null) =>
        new(new FakeOptionsMonitor<SwitchboardOptions>(opts ?? new SwitchboardOptions()));

    // --- ':'-Heuristik ---

    [Test]
    public async Task Resolve_ModelWithColon_RoutesToOllama()
    {
        var router = CreateRouter();

        var (provider, model) = router.Resolve("codellama:13b");

        await Assert.That(provider).IsEqualTo("ollama");
        await Assert.That(model).IsEqualTo("codellama:13b");
    }

    [Test]
    [Arguments("llama3:latest")]
    [Arguments("mistral:7b-instruct")]
    [Arguments("phi3:mini")]
    public async Task Resolve_VariousColonModels_RoutesToOllama(string modelName)
    {
        var router = CreateRouter();

        var (provider, _) = router.Resolve(modelName);

        await Assert.That(provider).IsEqualTo("ollama");
    }

    // --- Alias-Auflösung ---

    [Test]
    public async Task Resolve_KnownAlias_ResolvesViaColonHeuristic()
    {
        var opts = new SwitchboardOptions
        {
            ModelAliases = new Dictionary<string, string>
            {
                ["local-coder"] = "codellama:13b"
            }
        };
        var router = CreateRouter(opts);

        var (provider, model) = router.Resolve("local-coder");

        await Assert.That(provider).IsEqualTo("ollama");
        await Assert.That(model).IsEqualTo("codellama:13b");
    }

    [Test]
    public async Task Resolve_AliasWithoutColon_RoutesToAnthropic()
    {
        var opts = new SwitchboardOptions
        {
            ModelAliases = new Dictionary<string, string>
            {
                ["smart"] = "claude-3-5-sonnet-20241022"
            }
        };
        var router = CreateRouter(opts);

        var (provider, model) = router.Resolve("smart");

        await Assert.That(provider).IsEqualTo("anthropic");
        await Assert.That(model).IsEqualTo("claude-3-5-sonnet-20241022");
    }

    // --- Fallback zu Anthropic ---

    [Test]
    public async Task Resolve_UnknownModel_DefaultsToAnthropic()
    {
        var router = CreateRouter();

        var (provider, model) = router.Resolve("claude-3-opus-20240229");

        await Assert.That(provider).IsEqualTo("anthropic");
        await Assert.That(model).IsEqualTo("claude-3-opus-20240229");
    }

    [Test]
    public async Task Resolve_EmptyModel_DefaultsToAnthropic()
    {
        var router = CreateRouter();

        var (provider, model) = router.Resolve(string.Empty);

        await Assert.That(provider).IsEqualTo("anthropic");
        await Assert.That(model).IsEqualTo(string.Empty);
    }

    // --- Alias hat Vorrang vor ':'-Heuristik im Input ---

    [Test]
    public async Task Resolve_AliasSourceIgnoresColonInKey()
    {
        // Alias-Key mit ':' im Namen — unüblich, aber das System darf es auflösen
        var opts = new SwitchboardOptions
        {
            ModelAliases = new Dictionary<string, string>
            {
                ["ollama:wrapper"] = "claude-3-haiku-20240307"
            }
        };
        var router = CreateRouter(opts);

        var (provider, model) = router.Resolve("ollama:wrapper");

        // Alias-Lookup greift NICHT (kein Eintrag für "ollama:wrapper" als Key führt erst zu ':'-Check)
        // Da ':' heuristic NACH Alias-Lookup läuft, wird "ollama:wrapper" direkt zu Ollama gerouted
        // wenn kein Alias gefunden wird. Hier IST ein Alias → "claude-3-haiku-20240307" → kein ':'
        // → Anthropic
        await Assert.That(provider).IsEqualTo("anthropic");
        await Assert.That(model).IsEqualTo("claude-3-haiku-20240307");
    }
}

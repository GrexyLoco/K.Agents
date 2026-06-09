using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using System.Net.Http;

namespace K.Switchboard.Tests.Integration;

/// <summary>
/// Integrationstests für die ResourceGate-Verdrahtung im POST /v1/messages Endpoint.
/// Verifiziert: Substitution-Header wird gesetzt (Scenario 1) und 503 wird geschrieben (Scenario 2).
///
/// Teststrategie: WebApplicationFactory mit direkt gesetztem IOptionsMonitor{SwitchboardOptions}
/// (umgeht das Colon-in-DictionaryKey-Problem beim In-Memory-Config-Binder).
/// HardwareClasses leer → Probe nie aufgerufen (kein nvidia-smi/Ollama-Bedarf).
/// IHardwareProfileDetector gefakt → kein ProcessRunner-Aufruf.
/// "anthropic" HttpClient mit Stub-Handler → kontrollierte Upstream-Antwort in Scenario 1.
/// [NotInParallel] serialisiert gegen StatsEndpointTests (gleiche Gruppe): beide Klassen
/// starten WebApplicationFactory{Program} und teilen den statischen Serilog-Bootstrap-Logger —
/// parallele Initialisierung würde Freeze() doppelt auslösen.
/// </summary>
[NotInParallel("stats-integration")]
public sealed class ResourceGateEndpointTests
{
    // Minimales gültiges JSON-Body; model wird per Alias aufgelöst.
    // Alias "test-local-model" → "qwen2.5-coder:7b" (enthält ':' → Ollama-Routing → Gate greift)
    private const string RequestBody =
        """{"model":"test-local-model","max_tokens":10,"messages":[{"role":"user","content":"hi"}]}""";

    private const string LocalOllamaModel = "qwen2.5-coder:7b";

    // Anthropic-Stub: schlichtes 200 JSON (kein Streaming nötig für Header-Test)
    private static readonly string AnthropicStubBody =
        """{"id":"stub","type":"message","role":"assistant","content":[{"type":"text","text":"ok"}],"model":"claude-haiku-4-5","stop_reason":"end_turn","usage":{"input_tokens":5,"output_tokens":2}}""";

    /// <summary>
    /// Stub-Handler für den "anthropic" HttpClient — gibt 200 + JSON zurück.
    /// </summary>
    private sealed class StubAnthropicHandler : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken ct)
        {
            var resp = new HttpResponseMessage(System.Net.HttpStatusCode.OK)
            {
                Content = new StringContent(AnthropicStubBody, Encoding.UTF8, "application/json")
            };
            return Task.FromResult(resp);
        }
    }

    /// <summary>
    /// Fake-Detector: gibt ein neutrales HW-Profil zurück, damit HardwareProfileCache
    /// nie den echten ProcessRunner aufruft (kein nvidia-smi/wmic im Test-Prozess).
    /// </summary>
    private sealed class StubHardwareProfileDetector : IHardwareProfileDetector
    {
        public Task<HardwareProfile> DetectAsync(CancellationToken ct)
            => Task.FromResult(new HardwareProfile
            {
                TotalRamMb = 8192,
                Cores = 4,
                GpuVendor = "none",
                VramMb = 0,
                DetectedOn = DateTimeOffset.UtcNow
            });
    }

    /// <summary>
    /// Baut die für beide Szenarien passende SwitchboardOptions:
    /// - Alias test-local-model → qwen2.5-coder:7b (enthält ':' → Ollama-Routing)
    /// - HardwareClasses leer → kein Match → BuildSubstitution direkt, kein Live-Probe-Aufruf
    /// - ResourceGate.Enabled = true
    /// - Scenario 1: LocalModelTiers + TierSubstitutions gesetzt
    /// - Scenario 2: keine Tier-Einträge → Gate gibt Fail → 503
    /// </summary>
    private static SwitchboardOptions BuildOptions(bool withTierSubstitution) => new()
    {
        ResourceGate = new ResourceGateOptions { Enabled = true, CpuMaxLoadPercent = 85 },
        ModelAliases = new() { ["test-local-model"] = LocalOllamaModel },
        LocalModelTiers = withTierSubstitution
            ? new() { [LocalOllamaModel] = "S" }
            : new(),
        TierSubstitutions = withTierSubstitution
            ? new() { ["S"] = "claude-haiku-4-5" }
            : new(),
        HardwareClasses = [],    // leer → kein HW-Match → BuildSubstitution direkt
        FallbackChains = new(),
    };

    private static WebApplicationFactory<Program> CreateFactory(
        bool withTierSubstitution,
        HttpMessageHandler? anthropicHandler = null)
    {
        var opts = BuildOptions(withTierSubstitution);

        return new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                // Optionen direkt überschreiben (IOptionsMonitor + IOptions + IOptionsSnapshot)
                // um das Colon-in-Key-Problem beim In-Memory-Config-Binder zu umgehen.
                services.RemoveAll<IOptionsMonitor<SwitchboardOptions>>();
                services.RemoveAll<IOptions<SwitchboardOptions>>();
                services.RemoveAll<IOptionsSnapshot<SwitchboardOptions>>();
                services.AddSingleton<IOptionsMonitor<SwitchboardOptions>>(
                    new FakeOptionsMonitor<SwitchboardOptions>(opts));
                services.AddSingleton<IOptions<SwitchboardOptions>>(
                    Microsoft.Extensions.Options.Options.Create(opts));
                // IOptionsSnapshot ist scoped; einfacher Wrapper reicht für den Test.
                services.AddScoped<IOptionsSnapshot<SwitchboardOptions>>(
                    _ => new FakeOptionsSnapshot<SwitchboardOptions>(opts));

                // HW-Detektor durch Stub ersetzen → kein nvidia-smi / wmic
                services.RemoveAll<IHardwareProfileDetector>();
                services.AddSingleton<IHardwareProfileDetector, StubHardwareProfileDetector>();

                // CostingService isolieren (analog StatsEndpointTests)
                var tempDir = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
                Directory.CreateDirectory(tempDir);
                services.RemoveAll<CostingService>();
                services.AddSingleton<CostingService>(sp =>
                    new CostingService(
                        sp.GetRequiredService<IOptionsMonitor<SwitchboardOptions>>(),
                        sp.GetRequiredService<Microsoft.Extensions.Logging.ILogger<CostingService>>(),
                        tempDir));

                // "anthropic" HttpClient mit Stub-Handler verdrahten (Scenario 1)
                if (anthropicHandler is not null)
                {
                    services.AddHttpClient("anthropic")
                        .ConfigurePrimaryHttpMessageHandler(() => anthropicHandler);
                }
            });
        });
    }

    /// <summary>
    /// Scenario 1: Gate aktiviert, lokales Modell nicht ausführbar (keine HW-Klasse),
    /// TierSubstitution vorhanden → Substitution zu Claude → Header X-K-Switchboard-Substitution
    /// wird gesetzt, bevor FallbackService mit dem effektiven Claude-Modell forwards.
    /// </summary>
    [Test]
    public async Task GateAktiv_MitTierSubstitution_SetzSubstitutionHeader()
    {
        await using var factory = CreateFactory(
            withTierSubstitution: true,
            anthropicHandler: new StubAnthropicHandler());

        var client = factory.CreateClient();

        var request = new HttpRequestMessage(HttpMethod.Post, "/v1/messages")
        {
            Content = new StringContent(RequestBody, Encoding.UTF8, "application/json")
        };

        var response = await client.SendAsync(request);

        // Header muss gesetzt sein (Gate hat substituiert)
        await Assert.That(response.Headers.Contains("X-K-Switchboard-Substitution")).IsTrue();

        var headerValue = response.Headers.GetValues("X-K-Switchboard-Substitution").FirstOrDefault() ?? string.Empty;
        await Assert.That(headerValue).Contains("claude-haiku-4-5");
    }

    /// <summary>
    /// Scenario 2: Gate aktiviert, lokales Modell nicht ausführbar (keine HW-Klasse),
    /// KEIN TierSubstitut und KEINE FallbackChain → Gate gibt Fail → Endpoint schreibt 503.
    /// </summary>
    [Test]
    public async Task GateAktiv_OhneSubstitutOhneFallback_Liefert503()
    {
        await using var factory = CreateFactory(withTierSubstitution: false);

        var client = factory.CreateClient();

        var request = new HttpRequestMessage(HttpMethod.Post, "/v1/messages")
        {
            Content = new StringContent(RequestBody, Encoding.UTF8, "application/json")
        };

        var response = await client.SendAsync(request);

        await Assert.That((int)response.StatusCode).IsEqualTo(503);

        var body = await response.Content.ReadAsStringAsync();
        await Assert.That(body).Contains("Local model not viable");
    }
}

/// <summary>Minimale IOptionsSnapshot-Implementierung für Integration-Tests.</summary>
internal sealed class FakeOptionsSnapshot<T>(T value) : IOptionsSnapshot<T> where T : class
{
    public T Value => value;
    public T Get(string? name) => value;
}

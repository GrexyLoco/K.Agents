namespace K.Switchboard.Tests.Resources;

using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

/// <summary>
/// End-to-End-Verifikation der vollen Options-Pipeline (wie in Program.cs verdrahtet):
/// <c>.Configure&lt;SwitchboardOptions&gt;(config)</c> (Scalars + ResourceGate aus IConfiguration)
/// + <c>.PostConfigure</c> (colon-keyed Collections via <see cref="SwitchboardOptionsColonKeyLoader"/>)
/// → <c>IOptionsMonitor&lt;SwitchboardOptions&gt;.CurrentValue</c>. Fängt eine falsch verdrahtete
/// PostConfigure-Registrierung, die weder die Endpoint- noch die Loader-Isolations-Tests sehen würden.
/// </summary>
public sealed class OptionsCompositionTests
{
    [Test]
    public async Task Configure_plus_postconfigure_delivers_colon_keys_and_scalars()
    {
        var dir = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
        Directory.CreateDirectory(dir);
        var file = Path.Combine(dir, "config.json");

        // Produktions-Seed: CreateDefault via source-gen STJ serialisieren (wie Program.cs).
        var def = SwitchboardOptions.CreateDefault();
        await File.WriteAllTextAsync(file, JsonSerializer.Serialize(def, SwitchboardJsonContext.Default.SwitchboardOptions));

        // Volle Verdrahtung wie in Program.cs nachbauen.
        var config = new ConfigurationBuilder().AddJsonFile(file, optional: false).Build();
        var services = new ServiceCollection();
        services.Configure<SwitchboardOptions>(config);
        services.PostConfigure<SwitchboardOptions>(o => SwitchboardOptionsColonKeyLoader.ApplyFromFile(o, file));
        using var sp = services.BuildServiceProvider();

        var opts = sp.GetRequiredService<IOptionsMonitor<SwitchboardOptions>>().CurrentValue;

        // Colon-Keys kommen über PostConfigure (IConfiguration allein verlöre sie).
        await Assert.That(opts.LocalModelTiers["qwen2.5-coder:14b"]).IsEqualTo("L");
        await Assert.That(opts.LocalModelTiers["llama3.2:3b"]).IsEqualTo("S");
        // Scalars + nested ResourceGate kommen über IConfiguration.Configure.
        await Assert.That(opts.ResourceGate.Enabled).IsTrue();
        await Assert.That(opts.ResourceGate.CpuMaxLoadPercent).IsEqualTo(85);
        // TierSubstitutions (keine Colons) + HardwareClasses (Liste) durchgehend korrekt.
        await Assert.That(opts.TierSubstitutions["L"]).IsEqualTo("claude-sonnet-4-6");
        await Assert.That(opts.HardwareClasses.Count).IsEqualTo(5);
        await Assert.That(opts.HardwareClasses[^1].Name).IsEqualTo("cpu-32");
    }
}

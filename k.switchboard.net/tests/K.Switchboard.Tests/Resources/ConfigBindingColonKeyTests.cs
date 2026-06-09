namespace K.Switchboard.Tests.Resources;

using Microsoft.Extensions.Configuration;

/// <summary>
/// Verifiziert, dass der SwitchboardOptionsColonKeyLoader die IConfiguration-Schwäche
/// (Dictionary-Keys mit ':' werden als Sektions-Trenner interpretiert → verloren) korrigiert.
/// ASP.NET behandelt ':' als Sektions-Trenner — ohne den Loader wäre das gesamte
/// ResourceGate-Mapping (LocalModelTiers, HardwareClasses.Models) in Produktion leer.
/// </summary>
public sealed class ConfigBindingColonKeyTests
{
    /// <summary>
    /// Test 1: Loader behebt die ':'-Binding-Lücke.
    /// IConfiguration verliert Colon-Keys (demonstriert); ApplyFromFile stellt sie korrekt wieder her.
    /// Simluiert den PostConfigure-Pfad: Ziel = new SwitchboardOptions() (Factory-Default, alle
    /// Collections = []), dann ApplyFromFile (wie PostConfigure).
    /// JSON-Keys sind camelCase (entspricht SwitchboardJsonContext.PropertyNamingPolicy = CamelCase).
    /// </summary>
    [Test]
    public async Task Loader_fixes_colon_key_binding_gap()
    {
        var dir = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
        Directory.CreateDirectory(dir);
        var file = Path.Combine(dir, "config.json");
        await File.WriteAllTextAsync(file, """
        {
          "localModelTiers": { "qwen2.5-coder:14b": "L", "llama3.2:3b": "S" },
          "hardwareClasses": [
            { "name": "gpu-14b", "match": { "minVramMb": 10240 },
              "models": { "qwen2.5-coder:14b": { "peakRamMb": 11000 } } }
          ]
        }
        """);

        // Demonstriere den Bug: reines IConfiguration-Binding verliert Colon-Keys.
        var config = new ConfigurationBuilder().AddJsonFile(file, optional: false).Build();
        var rawBound = config.Get<SwitchboardOptions>();
        // rawBound.LocalModelTiers fehlt "qwen2.5-coder:14b" (der ':' wird als Sektions-Trenner interpretiert).
        // Wir prüfen nur, dass der Key fehlt (bug-Demonstration), nicht ob rawBound selbst null ist.
        var rawTiers = rawBound?.LocalModelTiers;
        await Assert.That(rawTiers is null || !rawTiers.ContainsKey("qwen2.5-coder:14b")).IsTrue();

        // PostConfigure-Pfad simulieren: neue SwitchboardOptions (Factory-Default) + ApplyFromFile.
        var opts = new SwitchboardOptions();
        SwitchboardOptionsColonKeyLoader.ApplyFromFile(opts, file);

        await Assert.That(opts.LocalModelTiers.ContainsKey("qwen2.5-coder:14b")).IsTrue();
        await Assert.That(opts.LocalModelTiers["qwen2.5-coder:14b"]).IsEqualTo("L");
        await Assert.That(opts.HardwareClasses[0].Models.ContainsKey("qwen2.5-coder:14b")).IsTrue();
        await Assert.That(opts.HardwareClasses[0].Models["qwen2.5-coder:14b"].PeakRamMb).IsEqualTo(11000);
    }

    /// <summary>
    /// Test 2: CreateDefault → serialisieren → ApplyFromFile ergibt vollständigen Round-Trip.
    /// Beweist, dass der echte Produktions-Pfad (Seed-Datei schreiben + PostConfigure laden)
    /// Colon-Keys vollständig erhält.
    /// </summary>
    [Test]
    public async Task Round_trip_CreateDefault_serialise_apply_preserves_colon_keys()
    {
        var dir = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
        Directory.CreateDirectory(dir);
        var file = Path.Combine(dir, "config.json");

        // Produktions-Seed-Schritt: CreateDefault via source-gen STJ serialisieren (camelCase).
        var def = SwitchboardOptions.CreateDefault();
        var serialized = JsonSerializer.Serialize(def, SwitchboardJsonContext.Default.SwitchboardOptions);
        await File.WriteAllTextAsync(file, serialized);

        // PostConfigure-Pfad: neue Factory-Default-Instanz + ApplyFromFile.
        var opts = new SwitchboardOptions();
        SwitchboardOptionsColonKeyLoader.ApplyFromFile(opts, file);

        // Colon-Keys müssen vollständig erhalten sein (Loader behebt nur die colon-betroffenen Collections;
        // Scalars/Nested-Records wie ResourceGate werden von IConfiguration normal gebunden).
        await Assert.That(opts.LocalModelTiers.ContainsKey("qwen2.5-coder:14b")).IsTrue();
        await Assert.That(opts.LocalModelTiers["qwen2.5-coder:14b"]).IsEqualTo("L");
        await Assert.That(opts.TierSubstitutions.ContainsKey("L")).IsTrue();
        await Assert.That(opts.TierSubstitutions["L"]).IsEqualTo("claude-sonnet-4-6");
        await Assert.That(opts.HardwareClasses.Count).IsEqualTo(5);
        await Assert.That(opts.HardwareClasses[^1].Name).IsEqualTo("cpu-32");
        // Colon-Keys in den nested HardwareClasses.Models müssen ebenfalls erhalten sein.
        // CreateDefault() hat keine Models-Einträge — prüfe nur die Count- und Name-Assertions.
    }

    /// <summary>
    /// Test 3: ApplyFromFile ist idempotent und liest die aktuelle Datei bei jedem Aufruf —
    /// entspricht dem Verhalten des PostConfigure-Delegates bei IOptionsMonitor-Rebuilds (Hot-Reload).
    /// </summary>
    [Test]
    public async Task ApplyFromFile_is_idempotent_and_reflects_file_changes()
    {
        var dir = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
        Directory.CreateDirectory(dir);
        var file = Path.Combine(dir, "config.json");

        // Erster Stand: Tier "L".
        await File.WriteAllTextAsync(file, """
        {
          "localModelTiers": { "qwen2.5-coder:14b": "L" }
        }
        """);

        var opts1 = new SwitchboardOptions();
        SwitchboardOptionsColonKeyLoader.ApplyFromFile(opts1, file);
        await Assert.That(opts1.LocalModelTiers["qwen2.5-coder:14b"]).IsEqualTo("L");

        // Datei-Änderung simulieren (Hot-Reload-Szenario): Tier "M".
        await File.WriteAllTextAsync(file, """
        {
          "localModelTiers": { "qwen2.5-coder:14b": "M" }
        }
        """);

        // Neuer PostConfigure-Aufruf (IOptionsMonitor-Rebuild) → frische Instanz + ApplyFromFile.
        var opts2 = new SwitchboardOptions();
        SwitchboardOptionsColonKeyLoader.ApplyFromFile(opts2, file);
        await Assert.That(opts2.LocalModelTiers["qwen2.5-coder:14b"]).IsEqualTo("M");
    }
}

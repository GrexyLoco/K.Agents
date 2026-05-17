using System.Text.Json.Serialization;

namespace K.Switchboard;

/// <summary>
/// Source-Generated JSON Serialization Context — trim- und AOT-sicher.
/// Beinhaltet alle Typen, die in K.Switchboard explizit serialisiert werden.
/// </summary>
[JsonSerializable(typeof(SwitchboardOptions))]
[JsonSerializable(typeof(Dictionary<string, ModelUsage>))]
[JsonSerializable(typeof(ModelUsage))]
[JsonSerializable(typeof(DailyStats))]
[JsonSourceGenerationOptions(
    WriteIndented = true,
    PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase)]
internal sealed partial class SwitchboardJsonContext : JsonSerializerContext { }

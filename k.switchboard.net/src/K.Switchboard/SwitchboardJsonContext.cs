using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Mvc;
using System.Diagnostics.CodeAnalysis;

namespace K.Switchboard;

/// <summary>
/// Source-Generated JSON Serialization Context — trim- und AOT-sicher.
/// Beinhaltet alle Typen, die in K.Switchboard explizit serialisiert werden.
/// </summary>
[JsonSerializable(typeof(SwitchboardOptions))]
[JsonSerializable(typeof(Dictionary<string, ModelUsage>))]
[JsonSerializable(typeof(ModelUsage))]
[JsonSerializable(typeof(DailyStats))]
[JsonSerializable(typeof(ProblemDetails))]
[JsonSourceGenerationOptions(
    WriteIndented = true,
    PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase)]
[ExcludeFromCodeCoverage]
internal sealed partial class SwitchboardJsonContext : JsonSerializerContext { }

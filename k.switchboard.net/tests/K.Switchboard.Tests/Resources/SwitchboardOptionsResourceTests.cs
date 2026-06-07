namespace K.Switchboard.Tests.Resources;

using System.Text.Json;
using System.Text.Json.Serialization;

// Test-lokaler Source-Gen-Context (PropertyNameCaseInsensitive) — erforderlich weil
// JsonSerializerIsReflectionEnabledByDefault=false im Testprojekt (AOT-Posture).
[JsonSourceGenerationOptions(PropertyNameCaseInsensitive = true)]
[JsonSerializable(typeof(SwitchboardOptions))]
internal sealed partial class ResourceTestJsonContext : JsonSerializerContext;

public sealed class SwitchboardOptionsResourceTests
{
    [Test]
    public async Task Deserializes_resource_config_sections()
    {
        const string json = """
        {
          "LocalModelTiers": { "llama3.2:3b": "S", "qwen2.5-coder:14b": "L" },
          "TierSubstitutions": { "S": "claude-haiku-4-5", "L": "claude-sonnet-4-6" },
          "ResourceGate": { "enabled": true, "ramBufferMb": 0, "cpuLoadWindowSeconds": 4, "cpuMaxLoadPercent": 85 },
          "HardwareClasses": [
            { "name": "gpu-14b",
              "match": { "minRamMb": 24576, "gpuVendor": "NVIDIA", "minVramMb": 10240, "maxVramMb": 16383 },
              "models": { "qwen2.5-coder:14b": { "peakRamMb": 11000, "validatedOn": "rig-x", "latencyP50Ms": 4200, "score": "B" } } }
          ]
        }
        """;

        var opts = JsonSerializer.Deserialize(json, ResourceTestJsonContext.Default.SwitchboardOptions)!;

        await Assert.That(opts.LocalModelTiers["qwen2.5-coder:14b"]).IsEqualTo("L");
        await Assert.That(opts.TierSubstitutions["S"]).IsEqualTo("claude-haiku-4-5");
        await Assert.That(opts.ResourceGate.CpuMaxLoadPercent).IsEqualTo(85);
        await Assert.That(opts.HardwareClasses[0].Name).IsEqualTo("gpu-14b");
        await Assert.That(opts.HardwareClasses[0].Match.MinVramMb).IsEqualTo(10240);
        await Assert.That(opts.HardwareClasses[0].Models["qwen2.5-coder:14b"].PeakRamMb).IsEqualTo(11000);
    }
}

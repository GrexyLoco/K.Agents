// K.Switchboard .NET — Spike (Phase 0)
// Validiert: Single-File+Trimming, Serilog+OTel, JSON-Config+IOptionsMonitor, WindowsService
using Microsoft.Extensions.Options;
using OpenTelemetry.Logs;
using OpenTelemetry.Resources;
using Serilog;
using Serilog.Events;

// ── Spike-Aufgabe 3: Default-Config anlegen wenn nicht vorhanden ──────────────
var appDataConfig = Path.Combine(
    Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
    "K.Switchboard",
    "config.json");

if (!File.Exists(appDataConfig))
{
    Directory.CreateDirectory(Path.GetDirectoryName(appDataConfig)!);
    File.WriteAllText(appDataConfig, """
        {
          "Port": 3456,
          "AnthropicBaseUrl": "https://api.anthropic.com",
          "OllamaBaseUrl": "http://localhost:11434"
        }
        """);
    Console.WriteLine($"[Spike] Default-Config erstellt: {appDataConfig}");
}

// ── Spike-Aufgabe 2: Serilog konfigurieren (Console + File) ──────────────────
var logPath = Path.Combine(
    Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
    "K.Switchboard", "logs", "spike-.log");

Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Debug()
    .MinimumLevel.Override("Microsoft", LogEventLevel.Warning)
    .WriteTo.Console(outputTemplate: "[{Timestamp:HH:mm:ss} {Level:u3}] {Message:lj}{NewLine}{Exception}")
    .WriteTo.File(logPath, rollingInterval: RollingInterval.Day)
    .CreateLogger();

// ── Builder ───────────────────────────────────────────────────────────────────
var builder = WebApplication.CreateBuilder(args);

// Spike-Aufgabe 4: WindowsService-Integration
builder.Host.UseWindowsService(options => options.ServiceName = "K.Switchboard.Spike");

// Spike-Aufgabe 2: Serilog als Logging-Provider
builder.Host.UseSerilog();

// Spike-Aufgabe 3: JSON-Config aus %APPDATA%\K.Switchboard\config.json
builder.Configuration
    .AddJsonFile(appDataConfig, optional: false, reloadOnChange: true);

builder.Services
    .Configure<SwitchboardOptions>(builder.Configuration)
    .AddHealthChecks();

// Spike-Aufgabe 2: OpenTelemetry Logging-Exporter
builder.Logging.AddOpenTelemetry(otel =>
{
    otel.SetResourceBuilder(ResourceBuilder.CreateDefault().AddService("K.Switchboard.Spike"));
    otel.AddConsoleExporter();
});

// Spike-Finding: JSON Source Generation vor Build() registrieren
builder.Services.ConfigureHttpJsonOptions(o =>
    o.SerializerOptions.TypeInfoResolverChain.Insert(0, SwitchboardJsonContext.Default));

var app = builder.Build();

// ── Endpoints ─────────────────────────────────────────────────────────────────
app.MapHealthChecks("/health");

app.MapGet("/config", (IOptionsSnapshot<SwitchboardOptions> opts) =>
    TypedResults.Ok(opts.Value));

// Spike-Aufgabe 3: IOptionsMonitor — zeigt Reload-Verhalten
app.MapGet("/reload-check", (IOptionsMonitor<SwitchboardOptions> monitor) =>
    TypedResults.Ok(new ReloadCheckResponse(monitor.CurrentValue.Port, monitor.CurrentValue.AnthropicBaseUrl)));

var logger = app.Services.GetRequiredService<ILogger<Program>>();
logger.LogInformation("[Spike] Serilog + OTel aktiv. Config: {Config}", appDataConfig);
logger.LogInformation("[Spike] WindowsService-Support registriert.");

app.Run();

// ── Options-Record ────────────────────────────────────────────────────────────
internal sealed record SwitchboardOptions
{
    public int Port { get; init; } = 3456;
    public string AnthropicBaseUrl { get; init; } = "https://api.anthropic.com";
    public string OllamaBaseUrl { get; init; } = "http://localhost:11434";
}

// ── Spike-Finding: JSON Source Generation erforderlich für Trimming-Kompatibilität
// Alle Typen die über Minimal-API-Endpoints serialisiert werden müssen hier registriert sein.
[System.Text.Json.Serialization.JsonSerializable(typeof(SwitchboardOptions))]
[System.Text.Json.Serialization.JsonSerializable(typeof(ReloadCheckResponse))]
internal sealed partial class SwitchboardJsonContext : System.Text.Json.Serialization.JsonSerializerContext { }

internal sealed record ReloadCheckResponse(int Port, string AnthropicBaseUrl);

record WeatherForecast(DateOnly Date, int TemperatureC, string? Summary)
{
    public int TemperatureF => 32 + (int)(TemperatureC / 0.5556);
}

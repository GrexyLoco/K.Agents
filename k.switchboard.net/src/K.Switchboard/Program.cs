using Serilog;
using Serilog.Events;
using OpenTelemetry.Logs;
using OpenTelemetry.Resources;

// --- Serilog früh konfigurieren (Bootstrap-Logger für Startup-Fehler) ---
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Debug()
    .MinimumLevel.Override("Microsoft", LogEventLevel.Warning)
    .MinimumLevel.Override("System", LogEventLevel.Warning)
    .WriteTo.Console(outputTemplate: "[{Timestamp:HH:mm:ss} {Level:u3}] [{SourceContext}] {Message:lj}{NewLine}{Exception}")
    .CreateBootstrapLogger();

try
{
    var builder = WebApplication.CreateBuilder(args);

    // --- Windows Service Support ---
    builder.Host.UseWindowsService(options => options.ServiceName = "K.Switchboard");

    // --- Config: %APPDATA%\K.Switchboard\config.json (Hot-Reload, Pflicht nach erster Ausführung) ---
    var appDataConfig = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "K.Switchboard",
        "config.json");

    if (!File.Exists(appDataConfig))
    {
        Directory.CreateDirectory(Path.GetDirectoryName(appDataConfig)!);
        var defaultConfig = builder.Configuration.GetSection("Switchboard").Exists()
            ? System.Text.Json.JsonSerializer.Serialize(
                builder.Configuration.GetSection("Switchboard").Get<SwitchboardOptions>() ?? new SwitchboardOptions(),
                new System.Text.Json.JsonSerializerOptions { WriteIndented = true })
            : System.Text.Json.JsonSerializer.Serialize(new SwitchboardOptions(),
                new System.Text.Json.JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(appDataConfig, defaultConfig);
        Log.Information("[Bootstrap] Default-Config erstellt: {Path}", appDataConfig);
    }

    builder.Configuration.AddJsonFile(appDataConfig, optional: false, reloadOnChange: true);

    // --- Serilog vollständig konfigurieren ---
    var logDir = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "K.Switchboard", "logs");

    builder.Host.UseSerilog((ctx, services, cfg) => cfg
        .ReadFrom.Configuration(ctx.Configuration)
        .ReadFrom.Services(services)
        .MinimumLevel.Debug()
        .MinimumLevel.Override("Microsoft", LogEventLevel.Warning)
        .MinimumLevel.Override("System", LogEventLevel.Warning)
        .WriteTo.Console(outputTemplate: "[{Timestamp:HH:mm:ss} {Level:u3}] [{SourceContext}] {Message:lj}{NewLine}{Exception}")
        .WriteTo.File(
            path: Path.Combine(logDir, "k.switchboard-.log"),
            rollingInterval: RollingInterval.Day,
            retainedFileCountLimit: 7,
            outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] [{SourceContext}] {Message:lj}{NewLine}{Exception}"));

    // --- OpenTelemetry Logging ---
    builder.Logging.AddOpenTelemetry(otel =>
    {
        otel.SetResourceBuilder(ResourceBuilder.CreateDefault().AddService("K.Switchboard"));
        otel.AddConsoleExporter();
    });

    // --- Options + Health Checks ---
    builder.Services
        .Configure<SwitchboardOptions>(builder.Configuration)
        .AddHealthChecks();

    var app = builder.Build();

    app.MapHealthChecks("/health");

    app.MapGet("/config", (Microsoft.Extensions.Options.IOptionsSnapshot<SwitchboardOptions> opts) =>
        TypedResults.Ok(opts.Value));

    app.Run();
}
catch (Exception ex) when (ex is not HostAbortedException)
{
    Log.Fatal(ex, "[Bootstrap] K.Switchboard konnte nicht gestartet werden");
}
finally
{
    await Log.CloseAndFlushAsync();
}

using Serilog;
using Serilog.Events;
using OpenTelemetry.Logs;
using OpenTelemetry.Resources;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using System.Threading.RateLimiting;

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
            ? JsonSerializer.Serialize(
                builder.Configuration.GetSection("Switchboard").Get<SwitchboardOptions>() ?? new SwitchboardOptions(),
                SwitchboardJsonContext.Default.SwitchboardOptions)
            : JsonSerializer.Serialize(new SwitchboardOptions(),
                SwitchboardJsonContext.Default.SwitchboardOptions);
        File.WriteAllText(appDataConfig, defaultConfig);
        Log.Information("[Bootstrap] Default-Config erstellt: {Path}", appDataConfig);
    }

    builder.Configuration.AddJsonFile(appDataConfig, optional: false, reloadOnChange: true);

    // --- Port aus Konfiguration setzen ---
    var port = builder.Configuration.GetValue<int>("Port", 3456);
    builder.WebHost.UseUrls($"http://*:{port}");

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

    // --- JSON-Serialisierung: Source-Generated Context global registrieren ---
    // Behebt Bug #247: TypedResults.Ok(...) in /stats und /config schlägt unter
    // PublishTrimmed=true fehl, da Reflection-Metadata für DailyStats/SwitchboardOptions
    // entfernt wird. Der Source-Gen-Context stellt trim-sichere TypeInfo bereit.
    builder.Services.ConfigureHttpJsonOptions(opts =>
    {
        opts.SerializerOptions.TypeInfoResolverChain.Insert(0, SwitchboardJsonContext.Default);
    });

    // --- Options + Health Checks ---
    builder.Services
        .Configure<SwitchboardOptions>(builder.Configuration)
        .AddHealthChecks();

    builder.Services.AddRateLimiter(_ =>
    {
        var opts = builder.Configuration.Get<SwitchboardOptions>() ?? new SwitchboardOptions();
        var permitLimit = Math.Max(1, opts.RateLimitPermitLimit);
        var windowMinutes = Math.Max(1, opts.RateLimitWindowMinutes);

        _.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
        _.AddFixedWindowLimiter("proxy", limiter =>
        {
            limiter.PermitLimit = permitLimit;
            limiter.Window = TimeSpan.FromMinutes(windowMinutes);
            limiter.QueueLimit = 0;
            limiter.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
        });
    });

    // --- Provider + Routing (Phase 3) ---
    builder.Services.AddHttpClient();

    // Named Ollama-Client mit konfigurierbarem Timeout: lokale CPU-Inferenz groesserer
    // Modelle kann den .NET-Default von 100s ueberschreiten. Der Anthropic-Client
    // ("anthropic") bleibt bewusst auf dem kurzen Default.
    var ollamaOptions = builder.Configuration.Get<SwitchboardOptions>() ?? new SwitchboardOptions();
    builder.Services.AddHttpClient("ollama", client =>
    {
        client.Timeout = TimeSpan.FromSeconds(ollamaOptions.OllamaTimeoutSeconds);
    });

    builder.Services.AddSingleton<IProvider, AnthropicProvider>();
    builder.Services.AddSingleton<IProvider, OllamaProvider>();
    builder.Services.AddSingleton<ProviderRegistry>();
    builder.Services.AddSingleton<ModelRouter>();

    // --- Fallback + Costing (Phase 4) ---
    builder.Services.AddSingleton<CostingService>();
    builder.Services.AddSingleton<UsageRecordingQueue>();
    builder.Services.AddHostedService(sp => sp.GetRequiredService<UsageRecordingQueue>());
    builder.Services.AddSingleton<FallbackService>();

    var app = builder.Build();

    app.UseRateLimiter();

    app.MapHealthChecks("/health");

    if (app.Environment.IsDevelopment())
    {
        app.MapGet("/config", (IOptionsSnapshot<SwitchboardOptions> opts) =>
            TypedResults.Ok(opts.Value));
    }

    // --- Proxy-Endpoint: POST /v1/messages ---
    app.MapPost("/v1/messages", async (HttpContext ctx, ModelRouter router, FallbackService fallback, IOptionsSnapshot<SwitchboardOptions> options, CancellationToken ct) =>
    {
        if (!string.IsNullOrWhiteSpace(options.Value.ApiKey))
        {
            var provided = ctx.Request.Headers["X-Api-Key"].ToString();
            if (!string.Equals(provided, options.Value.ApiKey, StringComparison.Ordinal))
            {
                ctx.Response.StatusCode = StatusCodes.Status401Unauthorized;
                await ctx.Response.WriteAsJsonAsync(new ProblemDetails
                {
                    Title = "Unauthorized",
                    Detail = "Missing or invalid X-Api-Key header."
                },
                SwitchboardJsonContext.Default.ProblemDetails,
                cancellationToken: ct);
                return;
            }
        }

        ctx.Request.EnableBuffering();

        string requestedModel;
        try
        {
            using var doc = await JsonDocument.ParseAsync(ctx.Request.Body, cancellationToken: ct);
            requestedModel = doc.RootElement.TryGetProperty("model", out var prop)
                ? prop.GetString() ?? string.Empty
                : string.Empty;
        }
        catch (JsonException)
        {
            ctx.Response.StatusCode = StatusCodes.Status400BadRequest;
            await ctx.Response.WriteAsJsonAsync(new ProblemDetails
            {
                Title = "Invalid JSON payload",
                Detail = "Request body contains invalid JSON."
            },
            SwitchboardJsonContext.Default.ProblemDetails,
            cancellationToken: ct);
            return;
        }

        ctx.Request.Body.Position = 0;

        await fallback.ForwardWithFallbackAsync(ctx, requestedModel, ct);
    }).RequireRateLimiting("proxy");

    // --- Statistik-Endpoint: GET /stats ---
    app.MapGet("/stats", (CostingService costing) =>
        TypedResults.Ok(costing.GetDailyStats()));

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

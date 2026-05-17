var builder = WebApplication.CreateBuilder(args);

builder.Host.UseWindowsService(options => options.ServiceName = "K.Switchboard");

var app = builder.Build();

app.MapGet("/health", () => Results.Ok("Healthy"));

app.Run();

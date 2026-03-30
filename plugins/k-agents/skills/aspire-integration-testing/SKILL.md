---
name: aspire-integration-testing
description: .NET Aspire integration testing — DistributedApplicationTestingBuilder, AppHost test fixtures, service mocking, health check validation, TUnit with ClassDataSource. USE FOR: writing and debugging integration tests against Aspire-orchestrated services. DO NOT USE FOR: Aspire app configuration (use aspire-architecture) or unit tests without Aspire (use tunit-patterns).

# Aspire Integration Testing (TUnit-Adaption)

Adaptiert von: [Aaronontheweb/dotnet-skills](https://github.com/Aaronontheweb/dotnet-skills) (MIT)
**Angepasst für TUnit** (nicht xUnit wie im Original).

## Setup
```xml
<PackageReference Include="Aspire.Hosting.Testing" Version="*" />
<PackageReference Include="TUnit" Version="*" />
```

## AppHost als Test-Fixture
```csharp
public class AspireAppFixture : IAsyncDisposable
{
    public DistributedApplication App { get; private set; } = null!;
    public HttpClient ApiClient { get; private set; } = null!;

    public AspireAppFixture()
    {
        var builder = await DistributedApplicationTestingBuilder
            .CreateAsync<Projects.MyApp_AppHost>();
        
        // Optional: Services mocken oder konfigurieren
        builder.Services.ConfigureHttpClientDefaults(http =>
            http.AddStandardResilienceHandler());
        
        App = await builder.BuildAsync();
        await App.StartAsync();
        
        ApiClient = App.CreateHttpClient("api");
    }

    public async ValueTask DisposeAsync()
    {
        await App.DisposeAsync();
        ApiClient.Dispose();
    }
}
```

## Tests mit TUnit
```csharp
[Test]
[ClassDataSource<AspireAppFixture>(Shared = SharedType.PerTestSession)]
public async Task Api_HealthCheck_ReturnsHealthy(AspireAppFixture app)
{
    var response = await app.ApiClient.GetAsync("/health");
    
    await Assert.That((int)response.StatusCode).IsEqualTo(200);
}

[Test]
[ClassDataSource<AspireAppFixture>(Shared = SharedType.PerTestSession)]
public async Task Api_GetUsers_ReturnsData(AspireAppFixture app)
{
    var response = await app.ApiClient.GetAsync("/api/users");
    response.EnsureSuccessStatusCode();
    
    var users = await response.Content.ReadFromJsonAsync<List<UserResponse>>();
    await Assert.That(users).IsNotNull();
}
```

## Aspire-Dashboard in Tests
```csharp
// Dashboard-URL für Debugging
var dashboardUrl = App.GetEndpoint("aspire-dashboard");
// Logs und Traces live beobachten während Tests laufen
```

## Regeln
- `PerTestSession` Shared Scope um AppHost nur einmal zu starten
- Health Checks als erstes testen (Smoke Test)
- `CreateHttpClient("service-name")` nutzt Service Discovery
- Aspire Dashboard bleibt im Test verfügbar für Debugging

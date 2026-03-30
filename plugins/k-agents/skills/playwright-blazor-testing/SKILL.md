---
name: playwright-blazor-testing
description: Blazor E2E testing with Playwright and TUnit — TUnit.Playwright, browser automation, WebApplication test fixtures, Blazor rendering waits, screenshot capture on failure. USE FOR: writing end-to-end UI tests for Blazor apps, setting up Playwright test fixtures with TUnit. DO NOT USE FOR: Blazor component logic (use blazor-patterns), unit tests (use tunit-patterns), or Aspire integration tests (use aspire-integration-testing).

# Playwright Blazor Testing (TUnit-Adaption)

Adaptiert von: [Aaronontheweb/dotnet-skills](https://github.com/Aaronontheweb/dotnet-skills) (MIT)
**Angepasst für TUnit** (nicht xUnit wie im Original).

## Setup
```xml
<PackageReference Include="TUnit" Version="*" />
<PackageReference Include="TUnit.Playwright" Version="*" />
<PackageReference Include="Microsoft.Playwright" Version="*" />
```

```bash
# Playwright Browser installieren
pwsh bin/Debug/net10.0/playwright.ps1 install chromium
```

## TUnit + Playwright Basis-Pattern
```csharp
using TUnit.Core;
using TUnit.Playwright;
using Microsoft.Playwright;

[Test]
[ClassDataSource<BlazorAppFixture>(Shared = SharedType.PerTestSession)]
public async Task HomePage_LoadsSuccessfully(BlazorAppFixture app)
{
    var page = await app.Browser.NewPageAsync();
    await page.GotoAsync(app.BaseUrl);
    
    await Assert.That(await page.TitleAsync()).Contains("Home");
}
```

## Blazor-spezifische Patterns

### Auf Blazor-Rendering warten
```csharp
// Warten bis Blazor fertig gerendert hat
await page.WaitForSelectorAsync("[data-blazor-rendered='true']");

// Oder: Auf spezifisches Element warten
await page.WaitForSelectorAsync(".user-list-loaded");
```

### Interaktive Komponenten testen
```csharp
[Test]
[ClassDataSource<BlazorAppFixture>(Shared = SharedType.PerTestSession)]
public async Task UserForm_SubmitCreatesUser(BlazorAppFixture app)
{
    var page = await app.Browser.NewPageAsync();
    await page.GotoAsync($"{app.BaseUrl}/users/new");
    
    await page.FillAsync("[data-testid='email']", "test@example.com");
    await page.FillAsync("[data-testid='name']", "Max Mustermann");
    await page.ClickAsync("[data-testid='submit']");
    
    // Auf Navigation oder Bestätigung warten
    await page.WaitForURLAsync("**/users/*");
    await Assert.That(await page.TextContentAsync(".success-message"))
        .Contains("erstellt");
}
```

### Screenshot bei Fehler (TUnit After-Hook)
```csharp
[After(Test)]
public async Task CaptureScreenshotOnFailure(TestContext context)
{
    if (context.Result?.Status == Status.Failed && _page is not null)
    {
        var path = Join-Path für Screenshot...
        await _page.ScreenshotAsync(new() { Path = $"screenshots/{context.TestDetails.TestName}.png" });
    }
}
```

## Test-Fixture
```csharp
public class BlazorAppFixture : IAsyncDisposable
{
    public string BaseUrl { get; private set; } = null!;
    public IBrowser Browser { get; private set; } = null!;
    private IPlaywright _playwright = null!;
    private WebApplication _app = null!;

    public BlazorAppFixture()
    {
        // WebApplication starten
        var builder = WebApplication.CreateBuilder();
        _app = builder.Build();
        _app.RunAsync();
        BaseUrl = _app.Urls.First();
        
        // Playwright starten
        _playwright = await Playwright.CreateAsync();
        Browser = await _playwright.Chromium.LaunchAsync();
    }

    public async ValueTask DisposeAsync()
    {
        await Browser.DisposeAsync();
        _playwright.Dispose();
        await _app.DisposeAsync();
    }
}
```

## CI-Integration (GitHub Actions)
```yaml
- name: Install Playwright Browsers
  shell: pwsh
  run: pwsh bin/Release/net10.0/playwright.ps1 install chromium --with-deps
```

---
name: tunit-patterns
description: "TUnit testing framework \u2014 [Test], [Arguments], [MatrixDataSource], ClassDataSource<T> (DI fixtures), async assertions (Assert.That), lifecycle hooks (Before/After), parallel-by-default. USE FOR: writing .NET unit and integration tests with TUnit, structuring test projects, using DI in test fixtures. DO NOT USE FOR: PowerShell tests (use pester-patterns), Blazor E2E tests (use playwright-blazor-testing), or Aspire integration tests (use aspire-integration-testing)."
---

# TUnit Patterns 

## Grundstruktur
```csharp
[Test]
public async Task MethodName_Scenario_ExpectedResult()
{
    // Arrange
    var service = new UserService(mockRepo);
    
    // Act
    var result = await service.GetByIdAsync(userId);
    
    // Assert (immer async!)
    await Assert.That(result).IsNotNull();
    await Assert.That(result.Email).IsEqualTo("test@example.com");
}
```

## Parametrisierte Tests
```csharp
[Test]
[Arguments("valid@email.com", true)]
[Arguments("invalid", false)]
[Arguments("", false)]
public async Task ValidateEmail_WithInput_ReturnsExpected(string email, bool expected)
{
    var result = EmailValidator.IsValid(email);
    await Assert.That(result).IsEqualTo(expected);
}
```

## Matrix Tests
```csharp
[Test]
[MatrixDataSource]
public async Task Api_Responds_Correctly(
    [Matrix("GET", "POST", "PUT")] string method,
    [Matrix("/users", "/orders")] string endpoint)
{
    var response = await client.SendAsync(new HttpRequestMessage(new HttpMethod(method), endpoint));
    await Assert.That((int)response.StatusCode).IsLessThan(500);
}
```

## DI-basierte Fixtures
```csharp
[Test]
[ClassDataSource<WebAppFixture>(Shared = SharedType.PerTestSession)]
public async Task Endpoint_Returns_Ok(WebAppFixture app)
{
    var client = app.CreateClient();
    var response = await client.GetAsync("/health");
    await Assert.That(response.StatusCode).IsEqualTo(HttpStatusCode.OK);
}
```

## Lifecycle
- `[Before(Class)]` / `[After(Class)]` — statisch, einmal pro Klasse
- `[Before(Test)]` / `[After(Test)]` — pro Test-Instanz
- `TestContext` in `[After(Test)]` für Fehler-Handling (Screenshots etc.)

## Wichtig
- **Alle Tests laufen parallel** — State isolieren!
- **Assertions sind async** — `await Assert.That(...)` immer
- **Microsoft.Testing.Platform** — nicht VSTest

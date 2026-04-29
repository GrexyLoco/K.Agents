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

---

## TDD Red-Green-Refactor Zyklus

Der Red-Green-Refactor Zyklus ist die Kernmethodik für testgetriebene Entwicklung mit TUnit:

```text
┌──────────────────────────────────────────────────────────┐
│                    TDD RED-GREEN-REFACTOR                 │
│                                                          │
│  1. RED    │ TUnit Tester schreibt failing Tests         │
│            │ → dotnet test bestätigt: Tests schlagen fehl │
│            │                                             │
│  2. GREEN  │ Handoff → .NET Developer                    │
│            │ "Mach diese Tests grün, ändere keine Tests" │
│            │ → dotnet test bestätigt: Tests sind grün    │
│            │                                             │
│  3. REFACTOR │ TUnit Tester prüft:                       │
│            │ • Sind Assertions scharf genug?              │
│            │ • Fehlen Edge Cases?                         │
│            │ • Können Tests robuster werden?              │
│            │ → Bei neuen Tests: zurück zu RED             │
│            │ → Wenn komplett: Handoff → Code Reviewer     │
└──────────────────────────────────────────────────────────┘
```

**Red-Phase:** Failing Tests schreiben
```csharp
[Test]
public async Task CreateUser_WithValidEmail_ReturnsCreatedUser()
{
    // Arrange
    var service = new UserService(NSubstitute.Substitute.For<IUserRepository>());
    var request = new CreateUserRequest("test@example.com", "Test User");

    // Act
    var result = await service.CreateAsync(request);

    // Assert
    await Assert.That(result).IsNotNull();
    await Assert.That(result.Email).IsEqualTo("test@example.com");
    await Assert.That(result.Name).IsEqualTo("Test User");
}
```

**Regeln für TDD:**
- **Red zuerst** — Tests schreiben, `dotnet test` ausführen, Failure bestätigen
- **Minimal Green** — Beim Handoff an .NET Developer explizit: "Minimale Implementierung, keine Extras"
- **Tests nicht ändern in Green** — Der .NET Developer darf Tests nicht modifizieren
- **Refactor-Recht** — Nur der TUnit Tester darf Tests in der Refactor-Phase anpassen
- **Loop-Erkennung** — Maximal 3 Red-Green-Zyklen pro Feature, dann Review

---

## 3 Working Modes

TUnit Tester arbeitet in **drei verschiedenen Modi**, je nach Kontext:

### Modus 1: Test Strategist (Planungsphase)
**Wann:** Feature wird **vor der Implementierung** geplant
- Codebase analysieren für existierende Test-Patterns
- Feature-Scope und Acceptance Criteria verstehen
- Test-Strategie definieren (Unit/Integration/UI-Ebenen)
- Executable Test Skeletons schreiben (compilierbar mit `Assert.Fail`)
- Handoff an Planning Agent mit strukturierten Test Cases

### Modus 2: TDD Driver (Red-Green-Refactor)
**Wann:** Feature wird per TDD implementiert
- Failing Tests schreiben (Red)
- Handoff an .NET Developer für minimale Implementierung (Green)
- Tests in Refactor-Phase optimieren
- Code-Review nach abgeschlossenem Zyklus

### Modus 3: Klassisches Testing (Post-Implementation)
**Wann:** Code existiert bereits
- Zu testenden Code analysieren
- Test Cases aus Issue übernehmen
- Tests schreiben und validieren
- Bei Fehlern: Handoff mit konkretem Finding

**Modus-Erkennung:** Planning-Request → Modus 1. "TDD" erwähnt → Modus 2. Code existiert → Modus 3.

---

## Test-Skeleton-Template (Executable Tests)

Test Skeletons sind compilierbare `.cs`-Dateien, die das Verhalten vor der Implementierung definieren:

```csharp
/// <summary>
/// Test Skeleton für Issue #42 — User Registration Feature.
/// Diese Tests definieren das erwartete Verhalten und schlagen absichtlich fehl,
/// bis der Produktionscode implementiert ist.
/// </summary>
public sealed class UserRegistrationTests
{
    // --- Erfolgsfälle ---

    [Test]
    public async Task RegisterUser_WithValidEmail_ReturnsCreatedResult()
    {
        // Arrange
        var service = new UserService(new MockUserRepository());
        var request = new CreateUserRequest { Email = "user@example.com" };

        // Act
        var result = await service.RegisterAsync(request);

        // Assert
        await Assert.That(result).IsNotNull();
        await Assert.That(result.Email).IsEqualTo("user@example.com");
        await Assert.Fail("RED: Produktionscode noch nicht implementiert — siehe Issue #42");
    }

    [Test]
    [Arguments("user@example.com")]
    [Arguments("admin@company.de")]
    public async Task RegisterUser_WithVariousValidEmails_Succeeds(string email)
    {
        await Assert.Fail("RED: Produktionscode noch nicht implementiert — siehe Issue #42");
    }

    // --- Edge Cases ---

    [Test]
    [Arguments("")]
    [Arguments("   ")]
    [Arguments("not-an-email")]
    public async Task RegisterUser_WithInvalidEmail_ThrowsValidationException(string invalidEmail)
    {
        await Assert.Fail("RED: Produktionscode noch nicht implementiert — siehe Issue #42");
    }

    // --- Fehlerverhalten ---

    [Test]
    public async Task RegisterUser_WithDuplicateEmail_ReturnsConflict()
    {
        await Assert.Fail("RED: Produktionscode noch nicht implementiert — siehe Issue #42");
    }
}
```

**Skeleton-Regeln:**
- **Compilierbar** — Korrekte Klassen-/Methodenstruktur
- **Kategorisiert** — Erfolgsfälle, Edge Cases, Fehlerverhalten
- **Issue-Referenz** — `Assert.Fail` referenziert das zugehörige Issue
- **Parametrisiert** — `[Arguments]` oder `[MatrixDataSource]` wo sinnvoll
- **Naming:** `Method_Scenario_ExpectedResult`

---

## ClassDataSource DI-Patterns

Dependency Injection in Tests über `ClassDataSource` mit Lifecycle Management:

```csharp
// Fixture Definition
public sealed class DatabaseFixture : IAsyncLifetime
{
    private IContainer _container;
    public DbContext Context { get; private set; }

    public async Task InitializeAsync()
    {
        _container = new ContainerBuilder().Build();
        Context = _container.Resolve<DbContext>();
        await Context.Database.MigrateAsync();
    }

    public async Task DisposeAsync()
    {
        await Context.DisposeAsync();
        _container.Dispose();
    }
}

// Test mit ClassDataSource
[Test]
[ClassDataSource<DatabaseFixture>(Shared = SharedType.PerTestSession)]
public async Task Database_Query_Returns_Data(DatabaseFixture db)
{
    var result = await db.Context.Users.FirstOrDefaultAsync();
    await Assert.That(result).IsNotNull();
}

[Test]
[ClassDataSource<WebAppFixture>(Shared = SharedType.PerTest)]
public async Task Endpoint_Returns_Ok(WebAppFixture app)
{
    var client = app.CreateClient();
    var response = await client.GetAsync("/health");
    await Assert.That(response.StatusCode).IsEqualTo(HttpStatusCode.OK);
}
```

**Sharing Modes:**
- **PerTest** — Neue Instanz für jeden Test (isoliert, teuer)
- **PerTestSession** — Eine Instanz für alle Tests im Session (schnell, getreilter State)
- **None** — Keine DI, manuelles Setup

---

## ParallelLimit-Awareness (Performance bei Parallel-Tests)

TUnit führt **alle Tests standardmäßig parallel** aus. Für Ressourcen-beschränkungen:

```csharp
// Standard: Parallel
[Test]
public async Task FastUnitTest()
{
    // Keine Einschränkung, läuft mit allen anderen
}

// Custom Parallel Limit definieren
public class DatabaseLimit : IParallelLimit
{
    public const int MaxCount = 3;
    public static ResourceLimit MaxParallel { get; } = new(MaxCount);
}

// Ressourcen-limitiert: Max 3 gleichzeitig
[Test]
[ParallelLimit<DatabaseLimit>]
public async Task DatabaseTest()
{
    // Läuft mit max 2 anderen DB-Tests parallel
}

[Test]
[ParallelLimit<DatabaseLimit>]
public async Task AnotherDatabaseTest() { }

// Nicht parallel: Complete Isolation
[Test]
[NotInParallel]
public async Task StateChangingTest()
{
    // Wartet bis alle anderen Tests fertig sind
}
```

**Best Practices:**
- Shared State vermeiden oder `[NotInParallel]` verwenden
- `ClassDataSource` mit `Shared = SharedType.PerTestSession` für teure Fixtures
- `[ParallelLimit<>]` für IO-intensive Tests (DB, Netzwerk)
- Monitoring: `dotnet test --verbosity diagnostic` zeigt Parallelisierung

---

## Lifecycle-Hooks-Detail

TUnit-Lifecycle mit praktischen Beispielen:

```csharp
public sealed class LifecycleExampleTests
{
    // Einmal am Anfang der Klasse (statisch)
    [Before(Class)]
    public static async Task SetupClass(ClassHookContext context)
    {
        // Build globale Test-Resources (z.B. Docker-Container)
        Console.WriteLine("🔧 Class setup");
        await Task.CompletedTask;
    }

    // Vor jedem Test
    [Before(Test)]
    public async Task SetupTest(TestContext context)
    {
        Console.WriteLine($"📝 Test setup: {context.TestName}");
        await Task.CompletedTask;
    }

    // Der eigentliche Test
    [Test]
    public async Task Example_DoSomething_ReturnsResult()
    {
        await Assert.That(true).IsTrue();
    }

    // Nach jedem Test — mit Fehler-Handling
    [After(Test)]
    public async Task TeardownTest(TestContext context)
    {
        if (context.Result?.Status == Status.Failed)
        {
            // Screenshot, Logs, Debug-Info sammeln bei Fehler
            Console.WriteLine($"❌ Test failed: {context.TestName}");
            Console.WriteLine(context.Result.Exception);
        }
        await Task.CompletedTask;
    }

    // Einmal am Ende der Klasse (statisch)
    [After(Class)]
    public static async Task TeardownClass(ClassHookContext context)
    {
        // Global Resources aufräumen (z.B. Docker-Container stoppen)
        Console.WriteLine("🔧 Class teardown");
        await Task.CompletedTask;
    }
}
```

**Hook-Ausführungsreihenfolge:**
1. `[Before(Class)]` — einmalig, statisch
2. Für **jeden** Test:
   - `[Before(Test)]` — Setup
   - Test-Methode
   - `[After(Test)]` — Teardown (mit `TestContext`)
3. `[After(Class)]` — einmalig, statisch

**Best Practices:**
- `[Before(Class)]` für teure, wiederverwendbare Setup-Operationen
- `[Before(Test)]` für per-Test Isolation
- `[After(Test)]` nutzen um zu prüfen ob Test fehlgeschlagen ist
- State in Hooks isolieren — nicht zwischen Tests teilen

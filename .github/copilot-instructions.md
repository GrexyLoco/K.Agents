# Copilot Instructions

## Projekt-Konventionen

### C# / .NET 10
- Verwende C# 14 Features: Primary Constructors, Collection Expressions, Pattern Matching, Raw String Literals
- File-scoped Namespaces immer
- Nullable Reference Types immer aktiviert, keine `#nullable disable`
- Records für DTOs und Value Objects
- Sealed Classes als Default
- Async/Await: kein `async void`, kein `.Result`, kein `.Wait()`
- Global Usings in `GlobalUsings.cs`
- XML-Doc Comments an allen public Members

### Blazor
- Render Modes explizit setzen (`@rendermode InteractiveServer` etc.)
- Code-Behind (`.razor.cs`) bei komplexen Komponenten
- `[Parameter]` nur Parent→Child, `EventCallback` für Child→Parent
- `IDisposable` bei Event-Subscriptions

### .NET MAUI
- MVVM mit CommunityToolkit.Mvvm (`[ObservableProperty]`, `[RelayCommand]`)
- Shell-Navigation mit Query Parameters
- Platform-Code über Partial Classes

### ASP.NET Core APIs
- Minimal APIs mit `MapGroup` und Typed Results
- Request/Response als Records, nicht Domain Models
- FluentValidation für Input-Validierung
- Health Checks registrieren

### Entity Framework Core
- Fluent API in `IEntityTypeConfiguration<T>` (nicht Data Annotations)
- `AsNoTracking()` für Read-Only Queries
- `AsSplitQuery()` bei Include-Chains > 2 Ebenen
- Sprechende Migration-Namen (`AddUserEmailIndex`)

### PowerShell Core
- **`Write-Host` ist verboten — überall, auch in CI-Scripts** → `Write-Output`, `Write-Verbose`, `Write-Information`
- `#Requires -Version 7.4` an jeder Datei
- `Set-StrictMode -Version Latest` + `$ErrorActionPreference = 'Stop'`
- Pfade immer via `Join-Path` — keine String-Konkatenation mit `\`
- Case-Sensitivity beachten (Linux-Dateisystem)
- `[CmdletBinding()]` an jeder Function
- Approved Verbs verwenden
- GitHub Outputs: `"name=value" | Out-File -FilePath $env:GITHUB_OUTPUT -Append`

### Release-Prozess (K.Actions.ReleaseFlow)
- Branching: `feature/*` → `dev/vX.Y.Z` → `release/vX.Y.Z` → `main`
- Phasen: Alpha → Freeze → Beta → Stable
- GitHub App Token statt PATs
- Quality Gate: GitLeaks → PSScriptAnalyzer → Pester → Evaluation
- CI-Scripts in `.github/scripts/` auslagern (nicht inline YAML)

### ReleaseFlow-Bedienung
Vor jedem `git push feature/*` oder `fix/*`: `/releaseflow-push` Skill aufrufen.
Bei Merge-Konflikten (DIRTY-Status): `/releaseflow-conflict-fix` Skill aufrufen.
Train-Status prüfen: `/releaseflow-train-status` Skill aufrufen.

### Testing
- **.NET:** TUnit Framework (nicht xUnit/NUnit/MSTest)
  - Async Assertions: `await Assert.That(...)`
  - `[Test]`, `[Arguments]`, `[MatrixDataSource]`
- **PowerShell:** Pester 5.6.x
  - `Describe`/`Context`/`It` mit `Should`
  - Mocks in `BeforeAll`/`BeforeEach`

### GitHub Actions
- `shell: pwsh` (nicht `powershell`)
- Actions auf SHA pinnen
- `permissions:` Block mit least-privilege
- Caching für NuGet und dotnet restore

### Commits
- Conventional Commits: `<type>(<scope>): <beschreibung>`
- Scope Pflicht bei Monorepo-Änderungen
- Issue-Referenz am Ende: `(#42)`

### Sprache
- Code: Englisch
- Dokumentation, Kommentare, Commits: Deutsch

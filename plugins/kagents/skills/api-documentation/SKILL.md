---
name: api-documentation
description: API-Dokumentation — XML-Doc Comments (C#), Comment-Based Help (PowerShell), Parameter-Dokumentation. USE FOR: writing XML-Doc for public APIs, adding PowerShell Comment-Based Help, documenting method signatures. DO NOT USE FOR: inline code comments (use inline-documentation) or user-facing docs (use readme-patterns).
---

# API-Dokumentation

## XML-Doc Comments (C#)

**Struktur für public APIs:**

```csharp
/// <summary>
/// Erstellt einen neuen Datensatz mit den angegebenen Parametern.
/// </summary>
/// <param name="name">Der Name des Datensatzes (nicht leer).</param>
/// <param name="email">Gültige E-Mail-Adresse.</param>
/// <returns>Die erstelle Entity mit generierter ID und Timestamp.</returns>
/// <exception cref="ArgumentNullException">Wenn name oder email null ist.</exception>
/// <exception cref="ValidationException">Wenn die E-Mail ungültig ist.</exception>
/// <remarks>
/// Diese Methode triggert einen Event, wenn die Entity erfolgreich erstellt wurde.
/// Bei Duplikaten wird eine ValidationException geworfen.
/// </remarks>
/// <example>
/// <code>
/// var entity = await service.CreateAsync("Max", "max@example.de");
/// Console.WriteLine($"Created: {entity.Id}");
/// </code>
/// </example>
public async Task<Entity> CreateAsync(string name, string email)
```

**Tags:**
- `<summary>` – Was macht es? (1–2 Sätze)
- `<param>` – Jeder Parameter mit Constraints/Valid Values
- `<returns>` – Rückgabewert (außer void/Task ohne TResult)
- `<exception>` – Erwartete Exceptions (mit Bedingungen)
- `<remarks>` – Zusätzliche Details, Edge Cases
- `<example>` – Runnable Code-Beispiel

## Comment-Based Help (PowerShell)

```powershell
function Invoke-DataSync {
    <#
    .SYNOPSIS
        Synchronisiert Daten mit dem Remote-Server.

    .DESCRIPTION
        Lädt lokale Änderungen hoch und zieht Remote-Updates.
        Unterstützt Conflict-Resolution nach Timestamp.

    .PARAMETER Source
        Lokaler Pfad zur Datenquelle (muss existieren).

    .PARAMETER Destination
        Remote-Server-URL (z.B., https://api.example.com).

    .PARAMETER Force
        Überschreibt Konflikte mit lokaler Version.

    .OUTPUTS
        [PSCustomObject] mit Properties: Success, Synced (int), Conflicts (int).

    .EXAMPLE
        Invoke-DataSync -Source 'C:\data' -Destination 'https://api.example.com'
        
        Führt Standard-Sync mit Conflict-Prompts durch.

    .EXAMPLE
        Invoke-DataSync -Source 'C:\data' -Destination 'https://api.example.com' -Force
        
        Überschreibt alle Remote-Versionen mit lokalen Daten.

    .NOTES
        Erfordert PowerShell 7.0+. Verbindung wird automatisch validiert.
    #>
```

**Tags:**
- `.SYNOPSIS` – Was macht die Funktion? (1 Zeile)
- `.DESCRIPTION` – Detaillierte Erklärung
- `.PARAMETER` – Jeder Parameter mit Beschreibung
- `.OUTPUTS` – Rückgabewert-Typ und Properties
- `.EXAMPLE` – 2+ konkrete Beispiele mit Outputs
- `.NOTES` – Voraussetzungen, Performanz, Hinweise

## Parameter-Dokumentation

**Typen + Constraints explizit machen:**

```csharp
/// <param name="timeout">
/// Wartezeit in Millisekunden. Gültig: 100–60000. Default: 5000.
/// </param>
public async Task WaitAsync(int timeout = 5000)

/// <param name="mode">
/// Sync-Modus. Zulässige Werte: "merge", "overwrite", "manual".
/// Default: "manual".
/// </param>
public void SetMode(string mode)
```

## Example Code in Comments

**Regeln für Beispiele:**
- **Muss kompilieren/laufen** – Kein konzeptioneller Pseudocode
- **Kurz** – 3–5 Zeilen, nicht ein ganzes Feature
- **Real** – Echte Use-Cases, nicht nur Happy Path
- **Mit Fehlerbehandlung** – Falls relevant:

```csharp
/// <example>
/// <code>
/// try {
///     var result = await api.DeleteAsync(userId);
///     Console.WriteLine("Deleted: " + result.Id);
/// } catch (NotFoundException ex) {
///     Console.WriteLine("User not found: " + ex.Message);
/// }
/// </code>
/// </example>
```

## Tool Integration

**IntelliSense + Hover in VS:**
- XML-Doc in Summary Tags wird in IntelliSense angezeigt
- Parameter-Beschreibungen auf Hover
- Exception-Hinweise in Code-Completion

**PowerShell Help:**
```powershell
Get-Help Invoke-DataSync
Get-Help Invoke-DataSync -Full
Get-Help Invoke-DataSync -Example
```

## Checkliste

- [ ] Jede public Klasse, Methode, Property dokumentiert
- [ ] Summary startet mit Verb (Erstellt, Gibt, Prüft)
- [ ] Alle Parameter + Returns dokumentiert
- [ ] Exceptions mit Bedingungen aufgelistet
- [ ] Beispiel-Code ist ausführbar
- [ ] Keine Typos in Tags

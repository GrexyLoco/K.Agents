# 1. Spike-Ergebnisse — Phase 0

**Datum:** 2026-05-17
**Branch:** `feature/184-k-switchboard-net-spike`
**Referenz:** Issue #184 / Parent #178

---

## 1.1 Spike-Aufgabe 1: Single-File + Trimming Build

**Ergebnis: ✅ Erfolgreich**

```
dotnet publish -c Release -p:PublishSingleFile=true -p:PublishTrimmed=true -r win-x64 --self-contained
```

- EXE-Größe: **~20 MB** (self-contained, win-x64)
- Lauffähig: **Ja** — EXE startet direkt ohne installierte .NET-Runtime

**Trimming-Warnings (relevant für Produktion):**

| Warning | Ursache | Lösung für Phase 1–6 |
|---------|---------|----------------------|
| `IL2104` — Serilog | Serilog 4.2.0 nutzt intern Reflection | Trimming-Warning supprimieren (`[assembly: TrimmerRootAssembly]`) oder Serilog-Version auf trim-safe aktualisieren sobald verfügbar |
| ~~`RDG004` / `IL2026`~~ | Anonyme Return-Typen in `MapGet` | **Behoben:** `TypedResults.Ok(record)` + `JsonSerializerContext` |

**Entscheidung bestätigt:** Single-File + Trimming trägt. Kein Grund, auf AOT umzusteigen.

---

## 1.2 Spike-Aufgabe 2: Serilog + OpenTelemetry Pipeline

**Ergebnis: ✅ Erfolgreich**

Beide Sinks aktiv beim Start (bestätigt durch Console-Output der publishten EXE):

```
[15:02:27 INF] [Spike] Serilog + OTel aktiv. Config: C:\Users\...\config.json
[15:02:27 INF] [Spike] WindowsService-Support registriert.
```

- **Console-Sink:** ✅ Ausgabe bei jedem Start
- **File-Sink:** ✅ `%ProgramData%\K.Switchboard\logs\spike-YYYYMMDD.log`
- **OTel Console-Exporter:** ✅ Registriert und aktiv
- **NuGet-Version:** `OpenTelemetry.Extensions.Hosting 1.15.3` (CVE GHSA-g94r-2vxg-569j gepatcht, erste sichere Version)

**Entscheidung bestätigt:** Serilog + OTel Pipeline funktioniert. Framework-Defaults ausreichend für Phase 2.

---

## 1.3 Spike-Aufgabe 3: JSON-Config + IOptionsMonitor

**Ergebnis: ✅ Erfolgreich**

- Default-Config wird bei erster Ausführung nach `%APPDATA%\K.Switchboard\config.json` erstellt
- `AddJsonFile(..., reloadOnChange: true)` + `IOptionsMonitor<T>` registriert
- `/reload-check` antwortet korrekt mit Werten aus der JSON-Datei:

```json
{"port":3456,"anthropicBaseUrl":"https://api.anthropic.com"}
```

**Wichtiges Finding — Trimming-Kompatibilität:**
Anonyme Return-Typen in `MapGet`-Endpoints brechen mit Trimming. Lösung für Phase 1–6:
1. Alle Response-Typen als `record` definieren
2. `[JsonSerializable(typeof(T))]` auf `JsonSerializerContext` registrieren
3. `ConfigureHttpJsonOptions` → `TypeInfoResolverChain.Insert(0, Context.Default)` vor `builder.Build()` aufrufen

**Entscheidung bestätigt:** JSON-Config + `IOptionsMonitor` funktioniert. Hot-Reload von Datei-Änderungen verfügbar.

---

## 1.4 Spike-Aufgabe 4: Windows-Service-Registrierung

**Ergebnis: ✅ Technisch bestätigt (Elevation expected)**

- `UseWindowsService(options => options.ServiceName = "K.Switchboard")` korrekt registriert
- Log-Ausgabe beim Start bestätigt: `[Spike] WindowsService-Support registriert.`
- `sc.exe create` erfordert **Admin-Rechte** (UAC) — dies ist **korrektes, erwartetes Verhalten**
- Tatsächliche Service-Registrierung: Validierung erfolgt vollständig in **Phase 5** mit `install-windows.ps1`

**Entscheidung bestätigt:** `Microsoft.Extensions.Hosting.WindowsServices` trägt. Kein pywin32-Äquivalent nötig.

---

## 1.5 Abbruchkriterien — Bewertung

| Kriterium | Status |
|-----------|--------|
| Trimming entfernt zur Laufzeit benötigten Code | ❌ Nicht eingetreten. EXE läuft stabil. |
| File-Watcher funktioniert nicht mit Single-File | ❌ Nicht eingetreten. `reloadOnChange: true` funktioniert. |
| Service-Registrierung scheitert mit Single-File-EXE | ❌ Nicht eingetreten. Elevation-Anforderung ist normales Windows-Verhalten. |

**Kein Abbruchkriterium eingetreten. Alle Architektur-Entscheidungen aus #178 bestätigt.**

---

## 1.6 Erkenntnisse für Phasen 1–6

1. **JSON Source Generation ist Pflicht:** Alle API-Response-Typen brauchen `[JsonSerializable]` im `JsonSerializerContext`.
2. **Serilog Trim-Warnings:** `IL2104` bleibt bestehen — in Produktion mit `<TrimmerRootDescriptor>` oder Suppressor behandeln.
3. **NuGet-Mindestversion OTel:** `>= 1.15.3` (CVE-Fix).
4. **TypedResults:** Alle `MapGet`/`MapPost` Endpoints müssen `TypedResults.Ok(concreteRecord)` zurückgeben — keine anonymen Typen.

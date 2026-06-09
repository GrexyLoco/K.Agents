# Spec: ResourceGate Ausbau +2 (Prozess-Priorität + Live-Telemetrie)

- **Issue:** #268 (Ausbau-Stufe +2 — letzte Stufe)
- **Train:** v1.21.0 (offen; baut auf +1-Alpha `v1.21.0-alpha2` auf)
- **Branch:** `feature/268-resource-gate-plus2` (von `dev/v1.21.0`)
- **Datum:** 2026-06-09
- **Basis:** MVP + Ausbau +1 sind gemergt. Diese Stufe erweitert additiv.

## 1. Ziel & Scope

Zwei additive Features, beide **opt-in** und **read-only/best-effort** (kein Eingriff in die Routing-Entscheidung):
1. **Ollama-Prozess-Priorität** — lokalen Ollama-Prozess beim Start auf below-normal setzen, damit lokale Inferenz die Maschine nicht verdrängt.
2. **Live-Inferenz-Telemetrie** — tatsächliche Latenz + RAM-Delta + gemeldete Größe pro lokaler Inferenz erfassen, persistieren und loggen, als Datenquelle für die manuelle Mapping-Pflege.

**Vorgaben/Out of Scope:**
- **macOS wird NICHT unterstützt** (durchgehend, wie +1).
- **Keine automatische Selbst-Nachpflege der Admission** (User-Entscheidung): Telemetrie ist rein beobachtend; die committed `ModelValidation`-Werte werden NICHT zur Laufzeit überschrieben. Drift-frei.
- **Kein teures Background-RAM-Sampling** im Hot-Path: RAM-Delta via zwei billige GC-Punktmessungen.

## 2. Feature A: Ollama-Prozess-Priorität (opt-in)

### Config
- `ResourceGateOptions.LowerOllamaPriority` (bool, Default **false**).

### Komponente
- `IProcessController` (testbare Abstraktion): `IReadOnlyList<int> FindByName(string name)` + `bool TrySetBelowNormal(int pid)`. Produktiv: `ProcessController` über `System.Diagnostics.Process` (`GetProcessesByName`, `PriorityClass = ProcessPriorityClass.BelowNormal`).
- `OllamaPriorityService` (`IHostedService`): in `StartAsync` — nur wenn `LowerOllamaPriority == true` **und** `OllamaBaseUrl`-Host ∈ {`localhost`, `127.0.0.1`, `::1`}:
  - alle Prozesse `"ollama"` finden, je `TrySetBelowNormal` aufrufen, Ergebnis loggen (`LogInformation` bei Erfolg, `LogWarning` bei Fehlschlag — fehlende Rechte/kein Prozess).
  - Remote-`OllamaBaseUrl` → no-op + `LogInformation` („remote Ollama — Priorität nicht beeinflussbar").
  - macOS (`OSPlatform.OSX`) → übersprungen + Log.
- **best-effort:** jede `Process`-Operation in try/catch; ein Fehler bricht den App-Start NICHT ab.

### Plattform
- `Process.PriorityClass = ProcessPriorityClass.BelowNormal` ist cross-platform (Windows: BELOW_NORMAL_PRIORITY_CLASS; Linux: mappt auf positiven nice-Wert — *Senken* der Priorität braucht keine root-Rechte). macOS ausgeschlossen.

### Bewusste Grenze
- Einmalig beim Start. Startet Ollama später neu, bleibt es auf Default-Priorität bis zum nächsten K.Switchboard-Start (dokumentiert).

## 3. Feature B: Live-Inferenz-Telemetrie (beobachten + loggen)

### Config
- `ResourceGateOptions.RecordLocalInferenceStats` (bool, Default **false** — Schreib-Seiteneffekt pro lokalem Request).

### Messung (im `OllamaProvider.ForwardAsync`, innerhalb des `LocalInferenceGate`-Wrappers)
- **Latenz:** `Stopwatch` um den Upstream-Inferenz-Call (Start vor `SendAsync`, Stop nach Abschluss des Response-Schreibens) → End-to-End-`elapsedMs`.
- **RAM-Delta (billig, 2-Punkt-GC):** `preFree = FreeRamMb()` vor dem Call, `postFree = FreeRamMb()` nach dem Stream (beides `GC.GetGCMemoryInfo()`: `TotalAvailableMemoryBytes − MemoryLoadBytes`, wie in `LiveResourceProbe`). `ramDeltaMb = max(0, preFree − postFree)`.
  > **Ehrlich:** `ramDeltaMb` ist eine Delta-**Approximation** (systemweite GC-Last, kein exakter Peak; durch Fremdprozesse verrauschbar). Die `/api/ps`-gemeldete Größe dient als Quervergleich. KEIN Background-Sampling.
- **Größe:** die in `/api/ps` gemeldete Modellgröße (best-effort; via einer kleinen Hilfe analog `LiveResourceProbe`, oder weggelassen wenn nicht billig erreichbar — siehe §6).
- Nur wenn `RecordLocalInferenceStats == true` und der Call ein lokales (Ollama-)Modell war.

### Persistenz: `LocalStatsStore` → `learned-stats.json`
- Per-install (ApplicationData, **nicht committed**, `.gitignore` wie `hw-profile.json`).
- Aggregiert pro Modell: `{ Count, LastLatencyMs, AvgLatencyMs (running), MaxLatencyMs, LastRamDeltaMb, LastSizeMb, UpdatedOn }`.
- `Record(model, elapsedMs, ramDeltaMb, sizeMb)`: lädt (gecacht), aktualisiert die Aggregation, schreibt zurück (`SemaphoreSlim`-serialisiert, wie `CostingService`/`HardwareProfileCache`).
- JSON via source-gen: `learned-stats.json`-Wurzeltyp in `SwitchboardJsonContext` registrieren.
- Serilog: `LogInformation` pro erfasstem Lauf (Modell, elapsedMs, ramDeltaMb, sizeMb).

### Zweck (explizit)
- Liefert reale Betriebsdaten → der PO verfeinert die **committed** `ModelValidation` (`LatencyP50Ms`, `PeakRamMb`/`PeakVramMb`) manuell, dokumentiert in `eval-measurement.md`. **Keine** Laufzeit-Admission-Änderung.

## 4. DI-Verdrahtung
- `IProcessController → ProcessController` (Singleton).
- `OllamaPriorityService` als `AddHostedService`.
- `LocalStatsStore` (Singleton) → in `OllamaProvider` injiziert.

## 5. Config-Defaults (`CreateDefault()`)
```jsonc
"ResourceGate": {
  // … MVP+1-Felder …
  "lowerOllamaPriority": false,
  "recordLocalInferenceStats": false
}
```
Beide opt-in → backward-safe (bestehende Installationen unverändert).

## 6. Tests (TUnit)
- **OllamaPriorityService:** localhost-Erkennung (localhost/127.0.0.1/::1 → aktiv; remote-Host → no-op); opt-in (Flag false → kein Aufruf); best-effort (gemockter `IProcessController`, dessen `TrySetBelowNormal` false/Exception liefert → kein App-Start-Abbruch); macOS-Skip (sofern testbar via OSPlatform — sonst dokumentiert).
- **LocalStatsStore:** `Record` aggregiert korrekt (Count↑, Avg/Max/Last); Persistenz-Roundtrip (zweite Instanz liest `learned-stats.json` von Disk); source-gen-JSON-Roundtrip (camelCase, wie `HardwareProfileCache`-Test).
- **OllamaProvider-Telemetrie:** mit `RecordLocalInferenceStats=true` wird `LocalStatsStore.Record` mit plausibler Latenz aufgerufen (gemockter/fake Store); mit `false` NICHT aufgerufen. (Latenz/ramDelta-Werte selbst sind umgebungsabhängig → nur „Record wurde aufgerufen / nicht aufgerufen" + Argument-Plausibilität asserten.)
- Alle 107 Tests aus MVP+1 bleiben grün.

> **Hinweis zur `/api/ps`-Größe in der Telemetrie:** Falls die Erfassung im `OllamaProvider`-Hot-Path nicht billig/sauber machbar ist (extra HTTP-Call), wird `sizeMb` in §3 weggelassen und nur Latenz + ramDeltaMb erfasst. Die Implementierung wählt den billigeren Weg; der Plan entscheidet das endgültig.

## 7. Dokumentation
- `configuration.md`: `LowerOllamaPriority` + `RecordLocalInferenceStats` (beide opt-in, Default false); `learned-stats.json` (Ort, per-install, nicht committed, Inhalt); Hinweis: Telemetrie ist read-only, ändert die Admission NICHT.
- `resource-aware-routing.md`: Telemetrie als read-only Beobachtungs-Seitenkanal (kein Einfluss auf den Datenfluss); Prozess-Priorität als Maschinen-Schutz-Ergänzung (Blast-Radius-Abschnitt).
- `troubleshooting.md`: „Ollama-Priorität wird nicht gesenkt" (nicht localhost / fehlende Rechte / Flag aus / Ollama nach Start neu gestartet); „learned-stats.json wächst/Telemetrie" (Flag aus zum Deaktivieren).
- `eval-measurement.md`: `learned-stats.json` als Live-Datenquelle für die manuelle Verfeinerung der committed `ModelValidation`-Werte.

## 8. Akzeptanzkriterien (+2)
- [ ] `LowerOllamaPriority` (opt-in) + `OllamaPriorityService`: localhost-only, einmal beim Start, below-normal, best-effort, macOS-Skip
- [ ] `IProcessController`-Abstraktion (testbar) + `ProcessController`
- [ ] `RecordLocalInferenceStats` (opt-in) + Telemetrie im OllamaProvider: Latenz (Stopwatch) + ramDeltaMb (2-Punkt-GC), best-effort
- [ ] `LocalStatsStore` → `learned-stats.json` (per-install, gitignored, source-gen-JSON, SemaphoreSlim)
- [ ] Keine Laufzeit-Admission-Änderung (Telemetrie read-only); beide Flags Default false (backward-safe)
- [ ] CreateDefault-Defaults; `.gitignore` learned-stats.json; Docs (macOS nicht unterstützt); TUnit-Tests; 107 Tests bleiben grün

## 9. ReleaseFlow
- Branch `feature/268-resource-gate-plus2` → PR gegen `dev/v1.21.0`. `dotnet format` + lowercase Commit-Descriptions + Train-Check vor Push. `Ref #268` (kein Closes). Nach +2-Merge ist #268 vollständig umgesetzt → Train Richtung Freeze→Beta→Stable (schließt #268 beim Stable-Promo).

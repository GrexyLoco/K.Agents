# Changelog

Alle relevanten Änderungen an K.Switchboard werden in dieser Datei dokumentiert.
Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/).

## [Unreleased]

### Added

- **Konfigurierbarer Ollama-Timeout und keep_alive** (#252): Zwei neue Felder in
  `SwitchboardOptions` für den Ollama-Forwarding-Pfad. `OllamaTimeoutSeconds` (Default `600`)
  registriert einen benannten HttpClient `"ollama"` mit erhöhtem Timeout — lokale CPU-Inferenz
  größerer Modelle überschreitet häufig den .NET-Default von 100 s und lief zuvor in
  `TaskCanceledException`/Timeout-Retries. `OllamaKeepAlive` (Default `"30m"`) wird als
  `keep_alive` in den weitergeleiteten Ollama-Request aufgenommen, sodass das Modell nicht
  bereits nach 5 Minuten Idle entladen wird (vermeidet Cold-Load beim Folge-Request). Der
  Anthropic-Client bleibt bewusst auf dem kurzen Default-Timeout.

### Fixed

- **Anthropic-/SSE-Streaming-Traffic wird jetzt im Cost-Tracking erfasst** (#250): Die
  Token-Extraktion (`CostingService.TryExtractUsage`) verstand bisher nur nicht-gestreamte
  Einzel-JSON-Antworten mit Top-Level `usage`. Bei SSE-Streaming (`stream:true`, von Claude
  Code praktisch immer genutzt) warf `JsonDocument.Parse` auf dem `data: {...}`-Eventstrom und
  der Verbrauch wurde verworfen — das Tracking war blind für Claude. Jetzt wird der Body bei
  fehlgeschlagenem Einzel-JSON-Parse zeilenweise als SSE interpretiert; `usage` wird sowohl
  auf Top-Level als auch unter `message` ausgewertet und je Feld als Maximum über alle Events
  akkumuliert (korrekt für Anthropics kumulative `output_tokens` und Ollamas finales
  `message_delta`). Der bestehende Non-Streaming-Pfad bleibt unverändert.

- **GET /stats liefert HTTP 500 bei Trimmed-Publish behoben** (#247): `ConfigureHttpJsonOptions`
  registriert `SwitchboardJsonContext.Default` als globalen `TypeInfoResolverChain`-Eintrag.
  Damit steht die Source-Generated Serialisierung für `DailyStats`, `ModelUsage` und
  `SwitchboardOptions` (Endpoint `/config`) auch unter `PublishTrimmed=true` zur Verfügung,
  ohne dass Reflection-Metadata benötigt wird.

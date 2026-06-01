# Changelog

Alle relevanten Änderungen an K.Switchboard werden in dieser Datei dokumentiert.
Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/).

## [Unreleased]

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

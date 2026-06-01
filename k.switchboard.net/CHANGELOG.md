# Changelog

Alle relevanten Änderungen an K.Switchboard werden in dieser Datei dokumentiert.
Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/).

## [Unreleased]

### Fixed

- **GET /stats liefert HTTP 500 bei Trimmed-Publish behoben** (#247): `ConfigureHttpJsonOptions`
  registriert `SwitchboardJsonContext.Default` als globalen `TypeInfoResolverChain`-Eintrag.
  Damit steht die Source-Generated Serialisierung für `DailyStats`, `ModelUsage` und
  `SwitchboardOptions` (Endpoint `/config`) auch unter `PublishTrimmed=true` zur Verfügung,
  ohne dass Reflection-Metadata benötigt wird.

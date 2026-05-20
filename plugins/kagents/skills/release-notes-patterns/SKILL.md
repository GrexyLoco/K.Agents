---
name: release-notes-patterns
description: Release-Notes-Muster — User-fokussierte Notizen, Format, Audience-Perspektive. USE FOR: writing release notes, planning user communication, understanding user-centric documentation. DO NOT USE FOR: technical changelogs (use CHANGELOG.md with Keep a Changelog) or API docs.
---

# 1. Release-Notes-Muster

## 1.1 User-facing Release Notes

**Kern-Prinzip:** Was hat sich für Benutzer geändert? Nicht: "Refactored DbContext factory"

**Gut:**
- "Exports können jetzt als ZIP-Datei heruntergeladen werden"
- "Datumsangaben in der API folgen jetzt ISO 8601 (bisher nur Ticks)"
- "Performance: Listenseiten sind 40% schneller"

**Nicht gut:**
- "Updated System.Collections.Immutable to 9.0"
- "Reduced allocations in query parser"
- "Refactored authentication service"

## 1.2 Format & Template

```markdown
# Release 1.5.0 – 2026-04-29

## Neue Features

- **CSV-Export:** Alle Listen können jetzt als CSV exportiert werden
  - Unterstützt Custom Columns
  - Link: https://docs.example.com/csv-export

- **Dark Mode:** Neue optionale Dark-Theme Einstellung
  - Unter Settings > Appearance
  - Betrifft Web-UI und Desktop-Client

## Verbesserungen

- Login-Seite antwortet 3x schneller (Cache-Optimization)
- Error-Messages sind jetzt auch auf DE, FR, IT verfügbar
- Datei-Upload mit besseren Fortschrittsanzeigen

## Bugfixes

- **Kritisch:** Duplikat-Einträge wurden manchmal nicht erkannt (FixedWithID)
- Falsche Zeitzonen-Konvertierung für UTC-Zeiten behoben
- Mobile App stürzte beim Importieren großer Dateien ab

## Breaking Changes

- Endpoint `/api/v1/legacy` entfernt
  - **Migrationsanleitung:** Siehe https://docs.example.com/migration-v1-to-v2
  - Alle v2-Endpoints sind verfügbar seit Release 1.4.0

## Sicherheit

- XSS-Lücke in Rich-Text Editor gefixt
- API-Keys werden jetzt mit Scrypt statt PBKDF2 gehasht

## Downloads

- [Windows](https://github.com/example/releases/download/v1.5.0/app-1.5.0-windows.msi)
- [macOS](https://github.com/example/releases/download/v1.5.0/app-1.5.0-macos.dmg)
- [Linux](https://github.com/example/releases/download/v1.5.0/app-1.5.0-linux.tar.gz)
```

## 1.3 Audience Perspective

**Für verschiedene Rollen unterschiedlich schreiben:**

| Rolle | Fokus | Beispiel |
|-------|-------|---------|
| **End User** | Was kann ich jetzt Neues machen? | "Export now supports Excel format" |
| **Admin** | Was muss ich konfigurieren? | "New LDAP_SYNC_INTERVAL env var required" |
| **Developer** | Welche APIs haben sich geändert? | "UserService.GetAsync() signature changed, see migration guide" |
| **Operator** | Was für Deployment/Upgrade? | "Requires .NET 10, Database migration 202604_v1.5 needed" |

## 1.4 Breaking Changes Communication

**Immer:**
1. **Was ändert sich** – Kurz und klar
2. **Warum** – Business/Tech-Grund
3. **Migrationsanleitung** – Schritt-für-Schritt oder Link
4. **Deadline** – Wann wird die alte Version nicht mehr supported?

```markdown
## Breaking Changes

### API: Bearer Token Format Changed
- **Alte Format:** `Authorization: Bearer {token}`
- **Neues Format:** `Authorization: Bearer v2_{token}`
- **Grund:** Bessere Token-Versionierung
- **Migrationsanleitung:**
  1. Update Client-Code: `token = "v2_" + token`
  2. Re-authenticate nach Update
- **Unterstützung alt:** Bis 2026-07-29 (90 Tage)

### PowerShell: Module renamed
- Alte: `Get-DataExport`
- Neue: `Export-Data`
- **Update Script:** `Update-Module MyModule`
```

## 1.5 Link to Technical Changelog

Verweis auf GitHub Release-Notes oder CHANGELOG.md:

```markdown
---

**Vollständige Liste aller Änderungen:** [CHANGELOG.md](https://github.com/example/K.Agents/blob/main/CHANGELOG.md)

**Technische Details zu dieser Release:** [Release v1.5.0](https://github.com/example/K.Agents/releases/tag/v1.5.0)
```

## 1.6 Checkliste

- [ ] Mindestens 1 Feature/Improvement pro Section
- [ ] Keine Buzz-Words ("Enhanced", "Improved") ohne Details
- [ ] Breaking Changes haben Migration Guide
- [ ] Alle Links funktionieren (Docs, GitHub, Download)
- [ ] Für 3 verschiedene Rollen verständlich

---
name: init-project
description: "Bootstrappt ein neues Repo mit CLAUDE.md, path-scoped Rules und .gitignore-Eintrag für CLAUDE.local.md. Analysiert den Stack automatisch und fragt nach Lücken."
---

# 1. Init Project Skill

Du richtest ein neues Projekt für Claude Code ein.

## 1.1 Ablauf

1. Erkenne den Stack: dotnet sln, csproj, Test-Framework, CI-Config.
2. Erstelle `CLAUDE.md` im Projekt-Root mit:
   - Build- und Test-Befehlen
   - Erkanntem Stack und Projektstruktur
   - Bekannten Fallstricken die automatisch nicht erkannt werden (nachfragen)
3. Lege `.claude/rules/`-Struktur an — passe an erkannten Stack an:
   - `csharp.md` mit paths: `**/*.cs` (wenn .NET erkannt)
   - `blazor.md` mit paths: `**/*.razor, **/*.razor.cs` (wenn Blazor erkannt)
   - `tests.md` mit paths: `tests/**/*.cs` (wenn xUnit/NUnit erkannt)
   - `api.md` mit paths: `**/Controllers/**/*.cs, **/Endpoints/**/*.cs` (wenn ASP.NET Core erkannt)
4. Füge `CLAUDE.local.md` zu `.gitignore` hinzu.
5. Erstelle leere `CLAUDE.local.md` mit Platzhalter-Kommentaren.
6. Zeige alles zur Freigabe. Schreibe erst danach.

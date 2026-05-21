---
name: readme-patterns
description: README-Muster — Struktur, Quick Start, Badges, Verzeichnis. USE FOR: writing project READMEs, planning README structure, understanding README best practices. DO NOT USE FOR: API documentation (use api-documentation) or release notes (use release-notes-patterns).
---

# 1. README-Muster

## 1.1 README-Struktur

**Standard-Layout für professionelle READMEs:**

1. **Title** – Projektname + Kurzbeschreibung (1 Zeile)
2. **Badges** – Build Status, Version, License, Coverage
3. **Inhaltsverzeichnis (ToC)** – Für längere READMEs (>500 Zeilen)
4. **Beschreibung** – Was macht das Projekt? Problem + Lösung
5. **Quick Start** – Erste 5 Minuten zum Laufen
6. **Installation** – Dependencies, Systemanforderungen
7. **Verwendung** – Basis-Beispiele, übliche Workflows
8. **Beispiele** – 2–3 runnable Code-Samples
9. **Contributing** – Wie beitragen? (Link zu CONTRIBUTING.md)
10. **License** – MIT, Apache 2.0, etc.

## 1.2 Quick Start Section

Minimales Beispiel für 5 Minuten:

```markdown
## Quick Start

1. **Install:**
   \`\`\`bash
   dotnet add package MyProject
   \`\`\`

2. **Use:**
   \`\`\`csharp
   var client = new MyClient("api-key");
   var result = await client.FetchAsync();
   Console.WriteLine(result);
   \`\`\`

3. **Run Tests:**
   \`\`\`bash
   dotnet test
   \`\`\`
```

## 1.3 Badges

Häufige Badges (führen auf Status-Seite):

```markdown
[![Build Status](https://github.com/user/repo/workflows/CI/badge.svg)](https://github.com/user/repo/actions)
[![Version](https://img.shields.io/nuget/v/MyProject.svg)](https://nuget.org/packages/MyProject)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Coverage](https://img.shields.io/codecov/c/github/user/repo.svg)](https://codecov.io/gh/user/repo)
```

## 1.4 Beispiele-Section

**Good:** Runnable Code-Samples mit erwarteter Ausgabe

```markdown
## Examples

### Basic Usage
\`\`\`csharp
using MyProject;

var auth = new BasicAuth("user", "pass");
var api = new Client(auth);
var users = await api.Users.ListAsync();
foreach (var u in users)
    Console.WriteLine($"{u.Id}: {u.Name}");
// Output: 1: Alice, 2: Bob
\`\`\`

### Advanced: Custom Handler
\`\`\`csharp
var handler = new RetryHandler(maxRetries: 3);
var client = new Client(auth, handler);
\`\`\`
```

## 1.5 Regeln

- **Deutsch** für deutsche Projekte, sonst **Englisch**
- Code-Beispiele **müssen kompilieren/ausführen**
- Keine Prosa-Wüsten – **Kurz, praktisch, verlinkt**
- Link zu detaillierter Doku, nicht alles im README
- Update-Frequenz: Immer mit relevanten Code-Änderungen

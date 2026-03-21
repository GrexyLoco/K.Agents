# Installation & Setup

## Überblick: Wie kommen die Agents in dein Projekt?

Es gibt **drei Installationswege** mit unterschiedlichen Eigenschaften:

| Methode | Scope | Automatische Updates | Multi-Repo | Empfohlen für |
|---------|-------|---------------------|------------|--------------|
| **Plugin Marketplace** | User-global | Ja (`/plugin update`) | ✅ Einmal installieren, überall nutzen | Empfohlen |
| **VS Code Settings** | User-global | Ja (VS Code Marketplace-Sync) | ✅ Einmal konfigurieren, überall nutzen | Empfohlen |
| **Manuelle Kopie** | Pro Repo | Nein (manuell) | ❌ Pro Repo kopieren | Isolierte Projekte |

---

## Methode 1: Plugin Marketplace (Copilot CLI / Claude Code)

**Funktionsprinzip:** Du registrierst dieses Repo als „Marketplace" — eine Art privater App Store für AI-Customizations. Die `marketplace.json` sagt dem Tool, welche Plugins verfügbar sind. Die `plugin.json` in jedem Plugin definiert welche Agents, Skills, Hooks etc. enthalten sind.

> **Offizielle Dokumentation:**
> - [Agent Plugins in VS Code (Preview)](https://code.visualstudio.com/docs/copilot/customization/agent-plugins) — Microsoft
> - [Creating Agent Plugins for VS Code and Copilot CLI](https://www.kenmuse.com/blog/creating-agent-plugins-for-vs-code-and-copilot-cli/) — Ken Muse
> - [Extend your coding agent with .NET Skills](https://devblogs.microsoft.com/dotnet/extend-your-coding-agent-with-dotnet-skills/) — .NET Blog (Microsoft)

### Einrichtung via Copilot CLI

Die folgenden Befehle sind **Slash-Commands** die im **Copilot CLI-Prompt** ausgeführt werden — nicht in PowerShell oder Bash.

```bash
# 1. Copilot CLI starten (das hier ist der einzige Terminal-Befehl)
#    In PowerShell, Bash oder einem beliebigen Terminal:
copilot

# 2. Im Copilot CLI-Prompt (nicht im Terminal!):
/plugin marketplace add GrexyLoco/K.Agents

# 3. Plugin installieren:
/plugin install k-agents@k-agents

# 4. Prüfen:
/skills
/agents
```

### Einrichtung via Claude Code

Die folgenden Befehle werden im **Claude Code CLI-Prompt** ausgeführt — nicht in PowerShell oder Bash.

```bash
# 1. Claude Code starten (das hier ist der einzige Terminal-Befehl)
#    In PowerShell, Bash oder einem beliebigen Terminal:
claude

# 2. Im Claude Code Prompt (nicht im Terminal!):
/plugin marketplace add GrexyLoco/K.Agents

# 3. Plugin installieren:
/plugin install k-agents@k-agents

# 4. Prüfen:
/skills
/agents
```

### Update

Im **Copilot CLI- oder Claude Code-Prompt** (nicht im Terminal):

```
# Marketplace-Index aktualisieren
/plugin marketplace update k-agents

# Plugin auf neueste Version bringen
/plugin update k-agents@k-agents
```

### Multi-Repo-Verhalten

**Plugins werden auf User-Level installiert, nicht pro Workspace.** Das bedeutet:

- Du installierst das Plugin **einmal** und es ist in **allen** Workspaces verfügbar
- Bei einem Workspace mit 10 Repos haben alle Repos Zugriff auf die gleichen Agents und Skills
- Kein doppelter Token-Verbrauch, kein doppeltes Setup

### Token-Verbrauch (Context Window)

Skills verwenden **Progressive Disclosure** — ein dreistufiges Ladesystem:

1. **Discovery (immer geladen):** Nur `name` und `description` aus dem YAML-Frontmatter jedes Skills. Bei 27 Skills sind das ca. 50–100 Tokens — vernachlässigbar.
2. **Instructions (bei Bedarf):** Der vollständige SKILL.md-Body wird erst geladen, wenn Copilot erkennt, dass der Skill für die aktuelle Aufgabe relevant ist.
3. **Resources (bei Bedarf):** Zusätzliche Dateien im Skill-Ordner (Scripts, Templates) werden nur geladen, wenn der Skill sie referenziert.

**In der Praxis:** Bei einem typischen Prompt werden 1–3 Skills geladen, nicht alle 27. Der Token-Overhead ist minimal.

> **Quelle:** [Agent Skills in VS Code](https://code.visualstudio.com/docs/copilot/customization/agent-skills) — *"This three-level loading system means you can install many skills without consuming context. Copilot loads only what is relevant for each task."*

---

## Methode 2: VS Code Settings (VS Code Insiders / Stable)

**Funktionsprinzip:** Du trägst das Repo als Marketplace-URL in deine VS Code User Settings ein. VS Code erkennt die `marketplace.json` und bietet die Plugins zur Installation an — ähnlich wie VS Code Extensions.

> **Voraussetzung:** Preview-Feature aktivieren.

### Einrichtung

Alles in **VS Code** (kein Terminal nötig):

1. VS Code Settings öffnen (`Ctrl+,`)
2. Nach `chat.plugins.enabled` suchen → auf `true` setzen
3. Nach `chat.plugins.marketplaces` suchen → Array ergänzen:

```json
// settings.json (User-Level, nicht Workspace!)
// Öffnen via: Ctrl+Shift+P → "Preferences: Open User Settings (JSON)"
{
  "chat.plugins.enabled": true,
  "chat.plugins.marketplaces": [
    "GrexyLoco/K.Agents"
  ]
}
```

4. Extensions-Sidebar öffnen (`Ctrl+Shift+X`) → `@agentPlugins` in die Suche eingeben
5. `k-agents` auswählen und installieren

### Wichtige Hinweise

- Die Marketplace-Einstellung **muss auf User-Level** stehen, nicht in Workspace Settings
- In Dev Containern funktioniert die Marketplace-Registrierung aktuell nicht zuverlässig
- Einmal installiert, sind die Plugins in **allen Workspaces** verfügbar

> **Quelle:** [Agent Plugins in VS Code](https://code.visualstudio.com/docs/copilot/customization/agent-plugins) — *"By default, VS Code discovers plugins from copilot-plugins and awesome-copilot. You can add additional marketplaces with the chat.plugins.marketplaces setting."*

---

## Methode 3: Manuelle Kopie / Symlink

**Funktionsprinzip:** Die Dateien werden direkt in das `.github/`-Verzeichnis des Consumer-Repos kopiert. VS Code erkennt `.github/agents/` und `.github/skills/` automatisch.

> **Offizielle Dokumentation:**
> - [Custom Agents in VS Code](https://code.visualstudio.com/docs/copilot/customization/custom-agents)
> - [Agent Skills in VS Code](https://code.visualstudio.com/docs/copilot/customization/agent-skills)
> - [Custom Instructions](https://code.visualstudio.com/docs/copilot/customization/custom-instructions)

### Option A: Install-Script

Im **Terminal** (PowerShell Core / Bash), ausgeführt im Verzeichnis des K.Agents-Repos:

```powershell
# Copy-Modus (Standard)
./scripts/Install-KAgents.ps1 -TargetPath C:\Users\dein-user\source\repos\MeinProjekt

# Symlink-Modus (automatische Updates, erfordert ggf. Admin-Rechte auf Windows)
./scripts/Install-KAgents.ps1 -TargetPath ~/projects/mein-app -Mode symlink

# Dry-Run (zeigt was passieren würde, ohne Änderungen)
./scripts/Install-KAgents.ps1 -TargetPath ~/projects/mein-app -WhatIf
```

### Option B: Manuell kopieren

Im **Terminal** (PowerShell Core / Bash):

```bash
# Einmal klonen (beliebiges Verzeichnis)
git clone https://github.com/GrexyLoco/K.Agents.git ~/K.Agents

# In jedes Consumer-Repo kopieren (im Verzeichnis des Consumer-Repos ausführen)
cp -r ~/K.Agents/.github/agents/* .github/agents/
cp -r ~/K.Agents/.github/skills/* .github/skills/
cp ~/K.Agents/AGENTS.md ./AGENTS.md
cp ~/K.Agents/.github/copilot-instructions.md .github/copilot-instructions.md
```

### Option C: Symlink (Multi-Repo, ein Update reicht)

Im **Terminal** (PowerShell Core / Bash), im Verzeichnis jedes Consumer-Repos:

```bash
# Einmal klonen
git clone https://github.com/GrexyLoco/K.Agents.git ~/K.Agents

# In jedem Consumer-Repo verlinken
ln -s ~/K.Agents/.github/agents .github/agents
ln -s ~/K.Agents/.github/skills .github/skills
```

**Vorteil:** Ein `git pull` im K.Agents-Repo aktualisiert alle verlinkten Repos.
**Nachteil:** Symlinks funktionieren nicht in ZIP-Distributionen und können auf Windows Admin-Rechte erfordern.

### Multi-Repo bei manueller Kopie

Bei einem Workspace mit 10 Repos musst du die Dateien in **jedes Repo** kopieren. Das ist der Hauptnachteil gegenüber der Plugin-Methode.

**Alternativ:** Nutze VS Code Settings um einen zentralen Ordner zu definieren (in **VS Code Settings**, nicht im Terminal):

```json
// settings.json (User-Level)
// Öffnen via: Ctrl+Shift+P → "Preferences: Open User Settings (JSON)"
{
  "chat.agentFilesLocations": [
    "~/K.Agents/.github/agents"
  ],
  "chat.agentSkillsLocations": [
    "~/K.Agents/.github/skills"
  ]
}
```

So werden die Agents und Skills aus dem zentralen K.Agents-Ordner geladen, ohne in jedes Repo zu kopieren.

> **Quelle:** [Custom Agents in VS Code](https://code.visualstudio.com/docs/copilot/customization/custom-agents) — *"You can configure additional file locations for workspace custom agent files with the chat.agentFilesLocations setting."*

---

## Methode 4: Claude Code

Im **Terminal** (PowerShell Core / Bash):

```bash
# Claude Code starten
claude
```

Dann im **Claude Code Prompt** (nicht im Terminal):

```
# Plugin Marketplace
/plugin marketplace add GrexyLoco/K.Agents
/plugin install k-agents@k-agents
```

Oder manuell im **Terminal**:

```bash
cp -r .github/agents/* .claude/agents/
cp -r .github/skills/* .claude/skills/
```

> **Offizielle Dokumentation:**
> - [Claude Code Sub-Agents](https://code.claude.com/docs/en/sub-agents)
> - [Claude Code Skills](https://code.claude.com/docs/en/skills)

---

## Monorepo-Unterstützung

Wenn du in VS Code nur einen Unterordner eines Monorepos öffnest, werden Customizations im Repo-Root standardmäßig **nicht** gefunden.

Aktiviere dazu in **VS Code Settings** (`Ctrl+,`):

```json
// settings.json
{
  "chat.useCustomizationsInParentRepositories": true
}
```

> **Quelle:** [Customize AI in VS Code](https://code.visualstudio.com/docs/copilot/customization/overview) — *"Enable chat.useCustomizationsInParentRepositories to also discover customizations from the parent repository."*

---

## Visual Studio 2026

Custom Agents werden ab Visual Studio 2026 Version 18.4 unterstützt:

- Agents in `.github/agents/` werden automatisch erkannt
- Auswahl über den Agent Picker im Copilot Chat
- Skills über die `.github + MCP` Extension

> **Quelle:** [Custom Agents in Visual Studio](https://devblogs.microsoft.com/visualstudio/custom-agents-in-visual-studio-built-in-and-build-your-own-agents/)

---

## FAQ

### Verbrauchen 27 Skills nicht zu viele Tokens?
Nein. Im Discovery-Schritt werden nur Name und Description geladen (~50-100 Tokens für alle 27). Der vollständige Skill-Inhalt wird erst bei Bedarf geladen (1-3 Skills pro Prompt).

### Muss ich das Plugin in jedem Repo installieren?
Nein. Plugin-Installation ist User-global. Einmal installieren = in allen Repos verfügbar.

### Kann ich einzelne Agents/Skills deaktivieren?
Ja. In VS Code unter Extensions → Agent Plugins → Plugin rechtsklicken → Disable. Oder einzelne Skill-Ordner löschen.

### Funktioniert das auch ohne Internet?
Ja, sobald installiert. Die Plugin-Dateien liegen lokal. Nur für Updates wird Internet benötigt.

### Kann ich eigene Skills ergänzen ohne K.Agents zu forken?
Ja. Lege zusätzliche Skills in `.github/skills/` deines eigenen Repos an. Sie werden neben den Plugin-Skills erkannt. Lokale Skills haben Vorrang bei Namenskonflikten.

### Was ist der Unterschied zwischen `/plugin` und Terminal-Befehlen?
`/plugin`-Befehle sind **Slash-Commands** die im Chat-Eingabefeld von Copilot CLI oder Claude Code ausgeführt werden — nicht in PowerShell oder Bash. Terminal-Befehle wie `git`, `cp`, `ln -s` werden in deinem normalen Terminal ausgeführt.
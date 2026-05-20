# 1. Installation & Setup

## 1.1 Überblick: Wie kommen die Agents in dein Projekt?

Es gibt **vier Installationswege** mit unterschiedlichen Eigenschaften:

| Methode | Scope | Automatische Updates | Multi-Repo | Empfohlen für |
|---------|-------|---------------------|------------|--------------|
| **Plugin Marketplace** | User-global | Ja (`/plugin update`) | ✅ Einmal installieren, überall nutzen | Empfohlen |
| **VS Code Settings** | User-global | Ja (VS Code Marketplace-Sync) | ✅ Einmal konfigurieren, überall nutzen | Empfohlen |
| **Claude Code (CLI + Extension)** | User-global | Ja (`/plugin update`) | ✅ Einmal installieren, überall nutzen | Empfohlen |
| **Manuelle Kopie** | Pro Repo | Nein (manuell) | ❌ Pro Repo kopieren | Isolierte Projekte |

---

## 1.2 Methode 1: Plugin Marketplace (Copilot CLI / Claude Code)

**Funktionsprinzip:** Du registrierst dieses Repo als „Marketplace" — eine Art privater App Store für AI-Customizations. Die `marketplace.json` sagt dem Tool, welche Plugins verfügbar sind. Die `plugin.json` in jedem Plugin definiert welche Agents, Skills, Hooks etc. enthalten sind.

> **Offizielle Dokumentation:**
> - [Agent Plugins in VS Code (Preview)](https://code.visualstudio.com/docs/copilot/customization/agent-plugins) — Microsoft
> - [Creating Agent Plugins for VS Code and Copilot CLI](https://www.kenmuse.com/blog/creating-agent-plugins-for-vs-code-and-copilot-cli/) — Ken Muse
> - [Extend your coding agent with .NET Skills](https://devblogs.microsoft.com/dotnet/extend-your-coding-agent-with-dotnet-skills/) — .NET Blog (Microsoft)

### 1.2.1 Einrichtung via Copilot CLI

Die folgenden Befehle sind **Slash-Commands** die im **Copilot CLI-Prompt** ausgeführt werden — nicht in PowerShell oder Bash.

```bash
# 1. Copilot CLI starten (das hier ist der einzige Terminal-Befehl)
#    In PowerShell, Bash oder einem beliebigen Terminal:
copilot

# 2. Im Copilot CLI-Prompt (nicht im Terminal!):
/plugin marketplace add GrexyLoco/K.Agents

# 3. Plugin installieren:
/plugin install kagents@K.Agents

# 4. Prüfen:
/skills
/agents
```

### 1.2.2 Einrichtung via Claude Code

Die folgenden Befehle werden im **Claude Code CLI-Prompt** ausgeführt — nicht in PowerShell oder Bash.

```bash
# 1. Claude Code starten (das hier ist der einzige Terminal-Befehl)
#    In PowerShell, Bash oder einem beliebigen Terminal:
claude

# 2. Im Claude Code Prompt (nicht im Terminal!):
/plugin marketplace add GrexyLoco/K.Agents

# 3. Plugin installieren:
/plugin install kagents@K.Agents

# 4. Prüfen:
/skills
/agents
```

### 1.2.3 Update

Im **Copilot CLI- oder Claude Code-Prompt** (nicht im Terminal):

```
# Marketplace-Index aktualisieren
/plugin marketplace update K.Agents

# Plugin auf neueste Version bringen
/plugin update kagents@K.Agents
```

### 1.2.4 Multi-Repo-Verhalten

**Plugins werden auf User-Level installiert, nicht pro Workspace.** Das bedeutet:

- Du installierst das Plugin **einmal** und es ist in **allen** Workspaces verfügbar
- Bei einem Workspace mit 10 Repos haben alle Repos Zugriff auf die gleichen Agents und Skills
- Kein doppelter Token-Verbrauch, kein doppeltes Setup

### 1.2.5 Token-Verbrauch (Context Window)

Skills verwenden **Progressive Disclosure** — ein dreistufiges Ladesystem:

1. **Discovery (immer geladen):** Nur `name` und `description` aus dem YAML-Frontmatter jedes Skills. Bei 49 Skills sind das ca. 50–100 Tokens — vernachlässigbar.
2. **Instructions (bei Bedarf):** Der vollständige SKILL.md-Body wird erst geladen, wenn Copilot erkennt, dass der Skill für die aktuelle Aufgabe relevant ist.
3. **Resources (bei Bedarf):** Zusätzliche Dateien im Skill-Ordner (Scripts, Templates) werden nur geladen, wenn der Skill sie referenziert.

**In der Praxis:** Bei einem typischen Prompt werden 1–3 Skills geladen, nicht alle 49. Der Token-Overhead ist minimal.

> **Quelle:** [Agent Skills in VS Code](https://code.visualstudio.com/docs/copilot/customization/agent-skills) — *"This three-level loading system means you can install many skills without consuming context. Copilot loads only what is relevant for each task."*

---

## 1.3 Methode 2: VS Code Settings (VS Code Insiders / Stable)

**Funktionsprinzip:** Du trägst das Repo als Marketplace-URL in deine VS Code User Settings ein. VS Code erkennt die `marketplace.json` und bietet die Plugins zur Installation an — ähnlich wie VS Code Extensions.

> **Voraussetzung:** Preview-Feature aktivieren.

### 1.3.1 Einrichtung

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
5. `kagents` auswählen und installieren

### 1.3.2 Wichtige Hinweise

- Die Marketplace-Einstellung **muss auf User-Level** stehen, nicht in Workspace Settings
- In Dev Containern funktioniert die Marketplace-Registrierung aktuell nicht zuverlässig
- Einmal installiert, sind die Plugins in **allen Workspaces** verfügbar

> **Quelle:** [Agent Plugins in VS Code](https://code.visualstudio.com/docs/copilot/customization/agent-plugins) — *"By default, VS Code discovers plugins from copilot-plugins and awesome-copilot. You can add additional marketplaces with the chat.plugins.marketplaces setting."*

---

## 1.4 Methode 3: Manuelle Kopie (Repo-Level)

**Funktionsprinzip:** Die Dateien werden direkt in das `.github/`-Verzeichnis des Consumer-Repos kopiert. VS Code erkennt `.github/agents/` und `.github/skills/` automatisch.

> **Offizielle Dokumentation:**
> - [Custom Agents in VS Code](https://code.visualstudio.com/docs/copilot/customization/custom-agents)
> - [Agent Skills in VS Code](https://code.visualstudio.com/docs/copilot/customization/agent-skills)
> - [Custom Instructions](https://code.visualstudio.com/docs/copilot/customization/custom-instructions)

### 1.4.1 Manuell kopieren

Im **Terminal** (PowerShell Core / Bash):

```bash
# Einmal klonen (beliebiges Verzeichnis)
git clone https://github.com/GrexyLoco/K.Agents.git ~/K.Agents

# In jedes Consumer-Repo kopieren (im Verzeichnis des Consumer-Repos ausführen)
cp -r ~/K.Agents/plugins/kagents/agents/* .github/agents/
cp -r ~/K.Agents/plugins/kagents/skills/* .github/skills/
cp ~/K.Agents/AGENTS.md ./AGENTS.md
cp ~/K.Agents/.github/copilot-instructions.md .github/copilot-instructions.md
```

### 1.4.2 Multi-Repo bei manueller Kopie

Bei einem Workspace mit 10 Repos musst du die Dateien in **jedes Repo** kopieren. Das ist der Hauptnachteil gegenüber der Plugin-Methode.

**Alternativ:** Nutze VS Code Settings um einen zentralen Ordner zu definieren (in **VS Code Settings**, nicht im Terminal):

```json
// settings.json (User-Level)
// Öffnen via: Ctrl+Shift+P → "Preferences: Open User Settings (JSON)"
{
  "chat.agentFilesLocations": [
    "~/K.Agents/plugins/kagents/agents"
  ],
  "chat.agentSkillsLocations": [
    "~/K.Agents/plugins/kagents/skills"
  ]
}
```

So werden die Agents und Skills aus dem zentralen K.Agents-Ordner geladen, ohne in jedes Repo zu kopieren.

> **Quelle:** [Custom Agents in VS Code](https://code.visualstudio.com/docs/copilot/customization/custom-agents) — *"You can configure additional file locations for workspace custom agent files with the chat.agentFilesLocations setting."*

---

## 1.5 Methode 4: Claude Code (CLI + VS Code Extension)

Im **Terminal** (PowerShell Core / Bash):

```bash
# Claude Code starten
claude
```

Dann im **Claude Code Prompt** (nicht im Terminal):

```
# Plugin Marketplace
/plugin marketplace add GrexyLoco/K.Agents
/plugin install kagents@K.Agents
```

Oder manuell im **Terminal**:

```bash
cp -r .github/agents/* .claude/agents/
cp -r .github/skills/* .claude/skills/
```

### 1.5.1 Claude Code Extension (VS Code)

Alles in **VS Code**:

1. Extension-Ansicht oeffnen (`Ctrl+Shift+X`) und nach `Claude Code` suchen
2. Extension `anthropic.claude-code` installieren
3. Claude-Panel oeffnen und anmelden
4. Plugin-Dialog oeffnen (`/plugins`) und `kagents@K.Agents` installieren

Die Extension nutzt dieselbe Plugin-Basis wie die Claude CLI. Installierte Plugins und Marketplaces sind zwischen CLI und Extension synchron.

> **Offizielle Dokumentation:**
> - [Claude Code Sub-Agents](https://code.claude.com/docs/en/sub-agents)
> - [Claude Code Skills](https://code.claude.com/docs/en/skills)

---

## 1.6 Was das Plugin mitliefert

Neben Agents und Skills liefert das Plugin auch **Hooks** und **MCP-Server** automatisch aus. Diese müssen nicht separat konfiguriert werden.

### 1.6.1 Hooks (Guards & Audit-Trail)

Das Plugin registriert **Guards** (präventive Prüfungen vor einem Tool-Aufruf) und **Lifecycle-Hooks** (Logging nach jedem Tool-Aufruf).

#### Guards (PreToolUse)

| Guard | Matcher | Prüft | Break-Glass |
|-------|---------|-------|-------------|
| `secret-scanner.ps1` | — (alle Tools) | Secrets/Tokens im Tool-Input (API-Keys, Passwörter, Zertifikate) | `KAGENTS_SECRET_BYPASS=1` |
| `destructive-command-guard.ps1` | `Bash` | Destruktive Shell-Kommandos (`rm -rf`, `format`, `DROP TABLE` etc.) | `KAGENTS_DESTRUCTIVE_BYPASS=1` |
| `releaseflow-guardrail.ps1` | `Bash` | Direkte `gh pr create/merge` auf master ohne ReleaseFlow-Pfad | `RELEASEFLOW_BYPASS=1` |
| `crossplatform-lint-guard.ps1` | `Write` | Cross-Platform-Probleme in `.ps1`-Dateien (`Write-Host`, Hardcoded-Pfade etc.) | `KAGENTS_LINT_BYPASS=1` |
| `pre_tool_call.ps1` | — (alle Tools) | Kein Block — Logging + Session-Wechsel-Erkennung (Session Summary) | — |

#### Lifecycle-Hook (PostToolUse)

| Hook | Event | Funktion |
|------|-------|----------|
| `post_tool_call.ps1` | `PostToolUse` | Loggt Erfolg- (`post_tool_use`) und Fehler-Events (`post_tool_use_failure`); VS-Code-kompatibel |

**Break-Glass:** Bypass-Variable in der Shell setzen und den Agenten neu starten. Der Bypass wird ins Log geschrieben.

**Log-Format:** JSONL (ein JSON-Objekt pro Zeile), eine Datei pro Tag.
**Log-Pfad:** `${CLAUDE_PLUGIN_ROOT}/logs/` (innerhalb des Plugin-Verzeichnisses, nicht im Workspace).

Die Hooks sind in `plugins/kagents/hooks/hooks.json` (Claude Code Format) definiert. Die Datei verwendet `${CLAUDE_PLUGIN_ROOT}` Token-Syntax und OS-spezifische Command-Overrides.

**VS Code:** Hooks werden automatisch beim Plugin-Start aktiviert — keine manuelle Konfiguration nötig.
**Claude Code:** Hooks einmalig via `Install-Hooks.ps1` registrieren (User- oder Project-Scope).

#### Git Hook (commit-msg)

Der `commit-msg` Hook wird als nativer git Hook installiert — er läuft bei JEDEM Commit, unabhängig vom verwendeten Tool (Terminal, IDE, Script):

```powershell
# Nur git commit-msg Hook installieren:
./plugins/kagents/tools/Install-Hooks.ps1 -GitHooks

# Alle Hooks (Claude Code + git):
./plugins/kagents/tools/Install-Hooks.ps1 -Target All -GitHooks
```

**Bestehende Nutzer** (Upgrade von einer früheren Version): Der `conventional-commit-guard` PreToolUse-Hook wurde entfernt. Falls er noch in `~/.claude/settings.json` registriert ist, muss der Eintrag manuell gelöscht werden:
1. `~/.claude/settings.json` öffnen
2. Den Block mit `conventional-commit-guard.ps1` aus `hooks.PreToolUse` entfernen
3. Alternativ: `Install-Hooks.ps1 -Uninstall` + `Install-Hooks.ps1` ausführen (registriert alle aktuellen Hooks neu)

> **Wichtig:** Hooks werden von **Visual Studio 2026** nicht unterstützt (kein Plugin-System für Hooks).

> **Quelle:** [Agent Plugins — Hooks in plugins](https://code.visualstudio.com/docs/copilot/customization/agent-plugins#_hooks-in-plugins)

### 1.6.2 MCP-Server

Das Plugin liefert zwei MCP-Server mit, die automatisch gestartet werden:

| Server | Funktion |
|--------|----------|
| **Microsoft Learn** | Docs-Suche, API-Referenzen, Code-Beispiele (`microsoft_docs_search`, `microsoft_docs_fetch`, `microsoft_code_sample_search`) |
| **GitHub** | Issues, PRs, Repos, Code-Suche, Advisory Database |

Die Server sind in `.mcp.json` definiert und werden vom Plugin-System automatisch registriert.

**GitHub-Authentifizierung:** Verwendet `gh auth token` (GitHub CLI). Voraussetzung: `gh auth login` wurde einmalig ausgeführt.

> **Wichtig:** MCP-Server werden von **Visual Studio 2026** nicht unterstützt.

> **Quelle:** [Agent Plugins — MCP servers in plugins](https://code.visualstudio.com/docs/copilot/customization/agent-plugins#_mcp-servers-in-plugins)

### 1.6.3 Prüfen ob Hooks und MCPs aktiv sind

1. **Hooks:** Im Chat View auf `...` → `Show Agent Debug Logs` klicken — Hook-Events erscheinen im Log
2. **MCP-Server:** `Ctrl+Shift+P` → `MCP: List Servers` — Plugin-Server erscheinen in der Liste
3. **Tools:** Im Chat auf das Zahnrad-Icon → `Configure Tools` — MCP-Tools wie `microsoft_docs_search` müssen sichtbar sein

---

## 1.7 Monorepo-Unterstützung

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

## 1.8 Visual Studio 2026

Visual Studio 2026 unterstützt Custom Agents und Skills nativ. Es gibt **keinen Plugin-Marketplace** — die Installation erfolgt ausschließlich über das Dateisystem (User-Level Copy).

> **Wichtig:** Plugins, die über Copilot CLI (`/plugin install`), Claude CLI oder VS Code Plugin-Marketplaces installiert wurden, werden von Visual Studio 2026 **nicht** erkannt. VS 2026 nutzt ein eigenes Discovery-System — eine separate Installation ist erforderlich.

> **Mindestversion:** K.Agents erfordert **Visual Studio 2026 Version 18.5** (Insiders) oder höher. Ältere Versionen unterstützen keine User-Level Agents/Skills und werden nicht unterstützt.

| Feature | Verfügbar ab | Quelle |
|---------|-------------|--------|
| Custom Agents (Repo-Level) | 18.4.0 (Stable) | [Release Notes 18.4](https://learn.microsoft.com/en-us/visualstudio/releases/2026/release-notes#march-update-1840) |
| Agent Skills (Repo-Level) | 18.4.1 (Stable) | [Release Notes 18.4.1](https://learn.microsoft.com/en-us/visualstudio/releases/2026/release-notes#18.4.1) |
| **User-Level Agents** (`%USERPROFILE%\.github\agents\`) | **18.5 (Insiders)** | [Insiders Release Notes](https://learn.microsoft.com/en-us/visualstudio/releases/2026/release-notes-insiders#features) |
| **User-Level Skills** (`.github/skills/` etc.) | **18.5 (Insiders)** | [Insiders Release Notes](https://learn.microsoft.com/en-us/visualstudio/releases/2026/release-notes-insiders#features) |

> **Offizielle Dokumentation:**
> - [Use built-in and custom agents with GitHub Copilot](https://learn.microsoft.com/en-us/visualstudio/ide/copilot-specialized-agents?view=visualstudio) — Microsoft Learn (aktualisiert 26.03.2026)
> - [Custom Agents in Visual Studio: Built in and Build-Your-Own agents](https://devblogs.microsoft.com/visualstudio/custom-agents-in-visual-studio-built-in-and-build-your-own-agents/) — VS Blog (19.02.2026)
> - [Visual Studio 2026 Release Notes](https://learn.microsoft.com/en-us/visualstudio/releases/2026/release-notes) — Microsoft Learn

### 1.8.1 Voraussetzungen

1. **Visual Studio 2026 Version 18.5** (Insiders) oder höher
2. **GitHub Copilot Subscription** (Free, Pro, Business oder Enterprise)
3. Copilot Chat muss aktiv sein (Badge unten rechts in der Statusleiste)

### 1.8.2 Installation per Script (empfohlen)

Das Install-Script kopiert Agents und Skills auf **User-Level** — sie sind danach in **allen** Solutions/Repos verfügbar, ohne Dateien ins Repo zu kopieren.

Im **Terminal** (PowerShell Core):

```powershell
# 1. K.Agents klonen (einmalig)
git clone https://github.com/GrexyLoco/K.Agents.git ~/K.Agents

# 2. Install-Script ausführen
~/K.Agents/scripts/Install-KAgentsVS.ps1

# 3. Dry-Run (zeigt was passieren würde, ohne Änderungen)
~/K.Agents/scripts/Install-KAgentsVS.ps1 -WhatIf
```

Das Script kopiert in folgende Verzeichnisse (laut [Insiders Release Notes](https://learn.microsoft.com/en-us/visualstudio/releases/2026/release-notes-insiders#features)):

| Typ | Ziel-Pfad |
|-----|-----------|
| Agents | `%USERPROFILE%\.github\agents\` |
| Skills | `%USERPROFILE%\.github\skills\` |

Wenn das K.Agents Copilot-Plugin bereits installiert ist, kopiert `Install-KAgentsVS.ps1` keine Agents nach `%USERPROFILE%\.github\agents\`. Stattdessen werden nur bekannte K.Agents-Legacy-Dateien in diesem Verzeichnis bereinigt, um Duplikate im Agent Picker zu vermeiden.

Der Agents-Pfad kann in VS angepasst werden unter:
`Tools → Options → GitHub → Copilot Chat → Custom agents user directory`

### 1.8.3 Manuelle Installation

Falls du das Script nicht nutzen willst, kannst du die Dateien manuell kopieren.

Im **Terminal** (PowerShell Core):

```powershell
# K.Agents klonen (einmalig)
git clone https://github.com/GrexyLoco/K.Agents.git ~/K.Agents

# User-Level Verzeichnisse erstellen
New-Item -ItemType Directory -Path "$env:USERPROFILE\.github\agents" -Force
New-Item -ItemType Directory -Path "$env:USERPROFILE\.github\skills" -Force

# Agents und Skills kopieren
Copy-Item -Path ~/K.Agents/plugins/kagents/agents/* -Destination "$env:USERPROFILE\.github\agents\" -Force
Copy-Item -Path ~/K.Agents/plugins/kagents/skills/* -Destination "$env:USERPROFILE\.github\skills\" -Recurse -Force
```

> **⚠️ Manuelle Kopie übernimmt kein Tool-Mapping.** Die Agent-Dateien enthalten VS Code Tool Sets (`search`, `read`, `edit`), die in VS 2026 nicht funktionieren. Nutze bevorzugt die Scripts (`Install-KAgentsVS.ps1`, `Update-KAgentsVS.ps1`), die das Mapping automatisch durchführen.

### 1.8.4 Update

Voraussetzung: Lokales K.Agents-Repo ist aktuell (`git pull`).

```powershell
# Repo aktualisieren und Update-Script ausfuehren
Push-Location ~/K.Agents; git pull; Pop-Location
~/K.Agents/scripts/Update-KAgentsVS.ps1

# Dry-Run
~/K.Agents/scripts/Update-KAgentsVS.ps1 -WhatIf
```

Das Update-Script entfernt zuerst alle K.Agents-Dateien und kopiert dann die aktuelle Version. Eigene Agents/Skills im selben Verzeichnis bleiben erhalten.

Beim Agent-Teil gilt derselbe Duplikat-Schutz wie bei der Installation:

- **Plugin erkannt** (`%USERPROFILE%\.copilot\installed-plugins\kagents\kagents\agents\` vorhanden):
  - bekannte K.Agents-Legacy-Agentdateien in `%USERPROFILE%\.github\agents\` werden bereinigt
  - Agent-Kopie nach `%USERPROFILE%\.github\agents\` wird uebersprungen
- **Plugin nicht erkannt**:
  - normale Aktualisierung (entfernen + neu kopieren) wird ausgefuehrt

Eigene fremde `*.agent.md`-Dateien werden nicht entfernt.

### 1.8.5 Deinstallation

Entfernt **nur** die Agents und Skills, die aus K.Agents stammen. Eigene Custom Agents/Skills bleiben erhalten.

```powershell
~/K.Agents/scripts/Uninstall-KAgentsVS.ps1

# Dry-Run
~/K.Agents/scripts/Uninstall-KAgentsVS.ps1 -WhatIf
```

### 1.8.6 Prüfen ob es funktioniert

1. Visual Studio 2026 öffnen → Solution laden
2. Copilot Chat öffnen (`Ctrl+\, Ctrl+C` oder über den Copilot-Badge)
3. **Agent Picker** klicken (Dropdown oben im Chat) → Custom Agents müssen in der Liste erscheinen
4. Alternativ: `@dotnet-developer Erstelle eine Blazor-Komponente` eingeben
5. Über das **Tools-Icon** im Chat die verfügbaren Tool-Namen prüfen

> **Hinweis:** Hooks und MCP-Server werden in Visual Studio 2026 **nicht** unterstützt. Diese Features stehen nur über das Plugin-System in VS Code und Claude Code zur Verfügung. Das bedeutet: kein automatisches Logging und keine MCP-Tools (Microsoft Learn, GitHub) in VS 2026.

> **Quelle:** [Use built-in and custom agents](https://learn.microsoft.com/en-us/visualstudio/ide/copilot-specialized-agents?view=visualstudio#access-custom-agents) — *"In the Copilot Chat window, select the agent picker dropdown to see available agents."*

### 1.8.7 Wichtige Unterschiede zu VS Code, Copilot CLI und Claude

| Feature | VS Code | Copilot CLI | Claude CLI | Claude Code Extension (VS Code) | Visual Studio 2026 |
|---------|---------|-------------|------------|----------------------------------|-------------------|
| Plugin Marketplace | [✅ `chat.plugins.marketplaces`](https://code.visualstudio.com/docs/copilot/customization/agent-plugins#_configure-plugin-marketplaces) | [✅ `/plugin install`](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-finding-installing#installing-plugins) | [✅ `/plugin install`](https://code.claude.com/docs/en/discover-plugins#install-plugins) | [✅ UI + `/plugins`](https://code.claude.com/docs/en/ide-integrations#manage-plugins) | [❌ Fokus auf `.github/agents`/Skills, kein Plugin-Marketplace-Flow](https://learn.microsoft.com/en-us/visualstudio/ide/copilot-specialized-agents?view=vs-2022#create-a-custom-agent) |
| User-Level Agents | [✅ `~/.copilot/agents` + `chat.agentFilesLocations`](https://code.visualstudio.com/docs/copilot/customization/custom-agents#_custom-agent-file-locations) | [✅ Plugin-basiert](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-finding-installing) | [✅ `~/.claude/agents/`](https://code.claude.com/docs/en/sub-agents#choose-the-subagent-scope) | [✅ gemeinsame Basis mit Claude CLI](https://code.claude.com/docs/en/ide-integrations#configure-settings) | [✅ `%USERPROFILE%\.github\agents\`](https://learn.microsoft.com/en-us/visualstudio/ide/copilot-specialized-agents?view=vs-2022#create-a-custom-agent) |
| User-Level Skills | [✅ `~/.copilot/skills` + `chat.agentSkillsLocations`](https://code.visualstudio.com/docs/copilot/customization/agent-skills#create-a-skill) | [✅ Agent Skills Standard (inkl. Copilot CLI)](https://code.visualstudio.com/docs/copilot/customization/agent-skills#_agent-skills-standard) | [✅ `~/.claude/skills/`](https://code.claude.com/docs/en/skills#where-skills-live) | [✅ gemeinsame Basis mit Claude CLI](https://code.claude.com/docs/en/ide-integrations#configure-settings) | [✅ `%USERPROFILE%\.github\skills\` und `.github/skills/`](https://learn.microsoft.com/en-us/visualstudio/ide/copilot-agent-skills?view=visualstudio#skill-locations) |
| Plugin-Sharing / Discovery | [✅ entdeckt Copilot-CLI-Plugins aus `~/.copilot/installed-plugins/`](https://code.visualstudio.com/docs/copilot/customization/agent-plugins#_plugins-installed-by-github-copilot-cli) | [✅ Plugins sind in VS Code wiederverwendbar](https://code.visualstudio.com/docs/copilot/customization/agent-plugins#_plugins-installed-by-github-copilot-cli) | [✅ gleiche Plugin-Ebene wie Extension](https://code.claude.com/docs/en/ide-integrations#manage-plugins) | [✅ gleiche Plugin-Ebene wie CLI](https://code.claude.com/docs/en/ide-integrations#manage-plugins) | [❌ getrennte VS-Discovery ueber `.github`-Dateien](https://learn.microsoft.com/en-us/visualstudio/ide/copilot-specialized-agents?view=vs-2022#custom-agents) |
| Tool-Namen | [✅ Tool-Sets wie `#search` und `#edit`](https://code.visualstudio.com/docs/copilot/agents/agent-tools#_group-tools-with-tool-sets) | [✅ CLI-/Plugin-Commands (z. B. `copilot plugin ...`)](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-finding-installing) | [✅ interne Tools wie `Read`, `Edit`, `Bash`](https://code.claude.com/docs/en/sub-agents#available-tools) | [✅ Extension nutzt CLI-Basis, aber als GUI/Teilmenge](https://code.claude.com/docs/en/ide-integrations#vs-code-extension-vs-claude-code-cli) | [✅ einzelne Tools (`get_file`, `code_search`, ...)](https://learn.microsoft.com/en-us/visualstudio/ide/copilot-specialized-agents?view=vs-2022#specify-tools) |

> **⚠️ Kein direktes Sharing mit VS 2026:** VS Code/Copilot CLI und Claude CLI/Claude Extension koennen jeweils intern teilen. Visual Studio 2026 bleibt jedoch ein eigener Discovery-Pfad ueber `.github/agents` und `.github/skills`.

> **⚠️ Pro IDE nur eine Agent-Quelle verwenden:**
> In VS Code/Copilot und Claude Code sollte jeweils nur **eine** Quelle aktiv sein (Plugin **oder** manuelle Datei-Kopie), um Doppelanzeigen/Shadowing zu vermeiden.

> **⚠️ Tool-Namen:** VS Code verwendet **Tool Sets** (`search`, `read`, `edit`, `execute`, `web`), VS 2026 verwendet **einzelne Tool-Namen** (`get_file`, `code_search`, `replace_string_in_file`, …). Die Install- und Update-Skripte (`Install-KAgentsVS.ps1`, `Update-KAgentsVS.ps1`) transformieren die Tool-Namen automatisch beim Kopieren. Prüfe über das **Tools-Icon** im Copilot Chat, welche Tools verfügbar sind.
>
> **Mapping-Übersicht:**
>
> | VS Code Tool Set | VS 2026 Tools |
> |---|---|
> | `search` | `code_search`, `file_search`, `find_symbol`, `get_symbols_by_name` |
> | `read` | `get_file`, `get_errors`, `get_output_window_logs` |
> | `edit` | `create_file`, `replace_string_in_file`, `multi_replace_string_in_file`, `remove_file` |
> | `execute` | `run_command_in_terminal`, `run_build`, `run_tests`, `get_tests` |
> | `web` | `get_web_pages` |
>
> Zusätzlich werden `get_projects_in_solution` und `get_files_in_project` automatisch hinzugefügt.
> `githubRepo` wird entfernt — in VS 2026 wird GitHub als MCP Server konfiguriert.

---

## 1.9 Copilot Instructions (optional)

Copilot Chat und die CLIs wissen nicht automatisch, dass K.Agents installiert ist und wie der Orchestrator zu verwenden ist. Das **Instructions Template** erklaert Copilot Chat:

- Welche CLIs verfuegbar sind (`claude`, `copilot`)
- Wie der Orchestrator aufgerufen wird
- Welche Agenten fuer welche Aufgaben zustaendig sind
- Wie bei Rate Limits verfahren wird

### 1.9.1 Wohin werden die Instructions installiert?

| Scope | Pfad | Wirkung |
|-------|------|---------|
| **Global** (Standard) | `%USERPROFILE%\.github\copilot-instructions.md` | Gilt fuer alle Repos, die keine eigene Instructions-Datei haben |
| **Pro Repo** | `<repo>\.github\copilot-instructions.md` | Gilt nur fuer dieses Repo, ueberschreibt globale Instructions |

### 1.9.2 Automatisch via Install-Script (VS 2026)

Die VS 2026 Install- und Update-Scripts kopieren die Instructions **automatisch** global:

```powershell
# Agents, Skills UND Instructions installieren (Standard)
~/K.Agents/scripts/Install-KAgentsVS.ps1

# Nur Agents und Skills, OHNE Instructions
~/K.Agents/scripts/Install-KAgentsVS.ps1 -SkipInstructions
```

Bei Updates werden die Instructions ebenfalls automatisch aktualisiert:

```powershell
~/K.Agents/scripts/Update-KAgentsVS.ps1

# Update ohne Instructions
~/K.Agents/scripts/Update-KAgentsVS.ps1 -SkipInstructions
```

### 1.9.3 Manuell via Setup-Script (ohne VS 2026)

Wenn du **kein Visual Studio 2026** nutzt (nur CLIs und/oder VS Code), kannst du die Instructions separat installieren:

```powershell
# Global (fuer alle Repos)
~/K.Agents/scripts/Setup-Instructions.ps1

# Fuer ein einzelnes Repo
~/K.Agents/scripts/Setup-Instructions.ps1 -Path C:\repos\MeinProjekt

# Bestehende ueberschreiben
~/K.Agents/scripts/Setup-Instructions.ps1 -Force
```

Nach Repo-Installation den Projekt-Kontext anpassen:

```powershell
code C:\repos\MeinProjekt\.github\copilot-instructions.md
```

### 1.9.4 Testen

1. VS Code oder VS 2026 mit Copilot Chat oeffnen
2. Fragen: "Welche Agenten stehen dir zur Verfuegung?"
3. Erwartung: Antwort erwaehnt Orchestrator, spezialisierte Agenten und CLI-Aufruf-Pattern

---

## 1.10 FAQ

### 1.10.1 Verbrauchen 49 Skills nicht zu viele Tokens?
Nein. Im Discovery-Schritt werden nur Name und Description geladen (~50-100 Tokens für alle 49). Der vollständige Skill-Inhalt wird erst bei Bedarf geladen (1-3 Skills pro Prompt).

### 1.10.2 Muss ich das Plugin in jedem Repo installieren?
Nein. Plugin-Installation ist User-global. Einmal installieren = in allen Repos verfügbar.

### 1.10.3 Kann ich einzelne Agents/Skills deaktivieren?
Ja. In VS Code unter Extensions → Agent Plugins → Plugin rechtsklicken → Disable. Oder einzelne Skill-Ordner löschen.

### 1.10.4 Funktioniert das auch ohne Internet?
Ja, sobald installiert. Die Plugin-Dateien liegen lokal. Nur für Updates wird Internet benötigt.

### 1.10.5 Kann ich eigene Skills ergänzen ohne K.Agents zu forken?
Ja. Lege zusätzliche Skills in `.github/skills/` deines eigenen Repos an. Sie werden neben den Plugin-Skills erkannt. Lokale Skills haben Vorrang bei Namenskonflikten.

### 1.10.6 Was ist der Unterschied zwischen `/plugin` und Terminal-Befehlen?
`/plugin`-Befehle sind **Slash-Commands** die im Chat-Eingabefeld von Copilot CLI oder Claude Code ausgeführt werden — nicht in PowerShell oder Bash. Terminal-Befehle wie `git`, `cp`, `ln -s` werden in deinem normalen Terminal ausgeführt.

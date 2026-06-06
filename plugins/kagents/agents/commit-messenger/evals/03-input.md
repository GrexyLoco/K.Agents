# Eval-Input 03 — commit-messenger

**Aufgabe:** Generiere die Conventional-Commit-Message (erste Zeile) für die folgende Änderung.
**Original-Commit (Referenz, NICHT Teil des Modell-Inputs):** `docs(install): duplikat-schutz fuer install und update dokumentieren` (eacfb24)

```diff
diff --git a/INSTALLATION.md b/INSTALLATION.md
index 3262278..0d9d05f 100644
--- a/INSTALLATION.md
+++ b/INSTALLATION.md
@@ -359,6 +359,8 @@ Das Script kopiert in folgende Verzeichnisse (laut [Insiders Release Notes](http
 | Agents | `%USERPROFILE%\.github\agents\` |
 | Skills | `%USERPROFILE%\.github\skills\` |
 
+Wenn das K.Agents Copilot-Plugin bereits installiert ist, kopiert `Install-KAgentsVS.ps1` keine Agents nach `%USERPROFILE%\.github\agents\`. Stattdessen werden nur bekannte K.Agents-Legacy-Dateien in diesem Verzeichnis bereinigt, um Duplikate im Agent Picker zu vermeiden.
+
 Der Agents-Pfad kann in VS angepasst werden unter:
 `Tools → Options → GitHub → Copilot Chat → Custom agents user directory`
 
@@ -398,6 +400,16 @@ Push-Location ~/K.Agents; git pull; Pop-Location
 
 Das Update-Script entfernt zuerst alle K.Agents-Dateien und kopiert dann die aktuelle Version. Eigene Agents/Skills im selben Verzeichnis bleiben erhalten.
 
+Beim Agent-Teil gilt derselbe Duplikat-Schutz wie bei der Installation:
+
+- **Plugin erkannt** (`%USERPROFILE%\.copilot\installed-plugins\kagents\kagents\agents\` vorhanden):
+  - bekannte K.Agents-Legacy-Agentdateien in `%USERPROFILE%\.github\agents\` werden bereinigt
+  - Agent-Kopie nach `%USERPROFILE%\.github\agents\` wird uebersprungen
+- **Plugin nicht erkannt**:
+  - normale Aktualisierung (entfernen + neu kopieren) wird ausgefuehrt
+
+Eigene fremde `*.agent.md`-Dateien werden nicht entfernt.
+
 ### Deinstallation
 
 Entfernt **nur** die Agents und Skills, die aus K.Agents stammen. Eigene Custom Agents/Skills bleiben erhalten.
@@ -433,6 +445,9 @@ Entfernt **nur** die Agents und Skills, die aus K.Agents stammen. Eigene Custom
 
 > **⚠️ Kein Plugin-Sharing:** Jede IDE hat ein eigenes Discovery-System. Agents, die über Copilot CLI oder VS Code Marketplace installiert wurden, sind in VS 2026 **nicht** sichtbar. Umgekehrt genauso.
 
+> **⚠️ Pro IDE nur eine Agent-Quelle verwenden:**
+> In VS Code/Copilot und Claude Code sollte jeweils nur **eine** Quelle aktiv sein (Plugin **oder** manuelle Datei-Kopie), um Doppelanzeigen/Shadowing zu vermeiden.
+
 > **⚠️ Tool-Namen:** VS Code verwendet **Tool Sets** (`search`, `read`, `edit`, `execute`, `web`), VS 2026 verwendet **einzelne Tool-Namen** (`get_file`, `code_search`, `replace_string_in_file`, …). Die Install- und Update-Skripte (`Install-KAgentsVS.ps1`, `Update-KAgentsVS.ps1`) transformieren die Tool-Namen automatisch beim Kopieren. Prüfe über das **Tools-Icon** im Copilot Chat, welche Tools verfügbar sind.
 >
 > **Mapping-Übersicht:**
```

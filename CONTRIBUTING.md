# Contributing

## Neuen Agent hinzufügen

1. Erstelle `plugins/kagents/agents/[name].agent.md`
2. YAML-Frontmatter mit `name`, `description`, `tools`, `model`, optional `handoffs`
3. Agent-Body in Markdown: Rolle, Kernkompetenzen, Workflow, Regeln
4. Aktualisiere `plugins/kagents/.github/plugin.json`
5. Aktualisiere `README.md` (Agents-Tabelle)

## Neuen Skill hinzufügen

1. Erstelle Ordner `plugins/kagents/skills/[skill-name]/`
2. Erstelle `SKILL.md` mit YAML-Frontmatter (`name`, `description`)
3. Body: Anleitungen, Code-Beispiele, Best Practices
4. Aktualisiere `plugins/kagents/.github/plugin.json` (skills-Array)
5. Aktualisiere `README.md` (Skills-Tabelle)

## OSS-Skill adaptieren

Wenn ein Skill aus einem externen Repo stammt:

1. Quell-Repo und Lizenz im SKILL.md Header angeben: `Basiert auf: [repo](url) (MIT)`
2. An unsere Konventionen anpassen:
   - `Write-Host` → `Write-Information` (überall)
   - xUnit/NUnit → TUnit (async Assertions, `[Test]`, `[ClassDataSource]`)
   - Englische Beispiele beibehalten, deutsche Kommentare wo nötig
3. In `README.md` unter "OSS-adaptierte Skills" eintragen

## Konventionen

### Sprache
- **Code:** Englisch
- **Dokumentation, Kommentare, SKILL.md-Beschreibungen:** Deutsch
- **YAML-Frontmatter `description`:** Deutsch

### Commits
```
feat(agent): Neuen Security Auditor Agent hinzugefügt
fix(skill): TUnit-Pattern für Playwright korrigiert
docs(readme): Skill-Tabelle aktualisiert
chore(plugin): plugin.json um neuen Skill ergänzt
```

### Qualitätskriterien für Skills
- [ ] YAML-Frontmatter vollständig (`name`, `description`)
- [ ] `description` beschreibt wann der Skill genutzt werden soll
- [ ] Code-Beispiele kompilierbar (C#) / ausführbar (PowerShell)
- [ ] Keine `Write-Host`-Aufrufe in Beispielen
- [ ] xUnit/NUnit-Beispiele nach TUnit konvertiert (wenn Testing-Skill)
- [ ] Quell-Attribution bei OSS-adaptierten Skills

### Qualitätskriterien für Agents
- [ ] YAML-Frontmatter: `name`, `description`, `tools`, `model`
- [ ] `description` beschreibt den Trigger (wann wird dieser Agent genutzt?)
- [ ] Handoffs definiert (wenn sinnvoll)
- [ ] Workflow-Schritte beschrieben
- [ ] Regeln-Sektion vorhanden

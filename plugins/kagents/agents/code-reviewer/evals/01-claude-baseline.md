# Claude-Baseline 01 — ModelRouter.cs

**Findings (Referenz):**
- 🟡 **Verbesserung — `:`-Heuristik für Provider-Wahl fragil** (`Resolve`, Z.30): Ein aufgelöster Name mit `:` wird *immer* als Ollama interpretiert. Anthropic-Modellnamen enthalten heute kein `:`, aber die Kopplung „Doppelpunkt = Ollama" ist implizit. Empfehlung: explizites Provider-Mapping/Präfix statt Zeichen-Heuristik, oder zumindest dokumentierte Invariante.
- 💬 **Hinweis — keine Eingabe-Validierung** für `model` (null/leer): leerer Name routet still zu Anthropic mit leerem Modell. Früh validieren oder dokumentieren.

**Lob:** Saubere XML-Doku inkl. `<remarks>`-Reihenfolge, `sealed`, Primary Constructor, ein `options.CurrentValue`-Lesen (konsistent), klare SRP. **Kein Blocker/Wichtig.**

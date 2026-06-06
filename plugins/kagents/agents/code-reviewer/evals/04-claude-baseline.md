# Claude-Baseline 04 — OllamaProvider.BuildOllamaBodyAsync

**Findings (Referenz) — substanziellster Ausschnitt:**
- 🟠 **Wichtig — `GetValue<bool>()` / `GetValue<string>()` können werfen** (Z.67 `request["stream"]?.GetValue<bool>()`, Z.77 `message["role"]?.GetValue<string>()`): Bei unerwartetem JSON-Typ (z. B. `"stream":"true"` als String) wirft `GetValue<T>` `InvalidOperationException` — dieselbe Bug-Klasse wie der in #250 gefixte `GetInt32`-Fall. Empfehlung: defensiv parsen (`TryGetValue`/Typ-Check) und auf Default fallen.
- 🟡 **Verbesserung — stiller Fallback auf leeres Objekt** (Z.66 `as JsonObject ?? new JsonObject()`): ungültiges Request-JSON wird stillschweigend zu einem leeren Body; ein leeres `messages` würde unbemerkt an Ollama gehen. Mindestens loggen.
- 💬 **Hinweis — `static` mit wachsender Parameterliste** (`body, resolvedModel, keepAlive, ct`): bei weiteren Optionen ein `OllamaRequestOptions`-Objekt erwägen.

**Lob:** Klarer Anthropic→Ollama-Mapping, `leaveOpen:true` korrekt, `keep_alive` sauber durchgereicht (#252). **Kein Blocker.**

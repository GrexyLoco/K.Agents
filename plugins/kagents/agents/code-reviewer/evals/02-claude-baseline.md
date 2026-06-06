# Claude-Baseline 02 — AnthropicProvider.cs

**Findings (Referenz):**
- 💬 **Hinweis — `new HttpMethod(context.Request.Method)` pro Request** (Z.25): kleine Allokation/kein Caching; für gängige Methoden `HttpMethod.Get/Post` o. ä. wiederverwenden.
- 💬 **Hinweis — Header-Allowlist** (`ShouldPassThrough`): nur 4 Header werden weitergereicht; bewusst, aber dokumentieren, dass z. B. Custom-Header absichtlich gefiltert werden.
- 💬 **Hinweis — `ReadToEndAsync` puffert den ganzen Body** als String (`BuildContentAsync`): bei großen Payloads Allokation; für einen Proxy vertretbar.

**Lob:** Korrektes Streaming via `ResponseHeadersRead` + `CopyToAsync`, `Transfer-Encoding`-Entfernung kommentiert, `using` für Request/Response, OrdinalIgnoreCase-Vergleiche. **Kein Blocker/Wichtig** — sauberer Passthrough.

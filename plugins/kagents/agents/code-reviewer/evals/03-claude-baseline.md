# Claude-Baseline 03 — CostingService.cs (Cost + IO)

**Findings (Referenz):**
- 🟡 **Verbesserung — doppelte Aggregation in `GetDailyStats`** (Z.~116-118): `data.Values` wird zweimal durchlaufen (`total`, `totalSaved`). In einer Schleife (oder einem `Aggregate` mit Tupel) zusammenfassen.
- 💬 **Hinweis — breiter `catch (Exception ex)`** beim Speichern: bewusst nicht-fatal (Persistenz darf den Request nicht killen), aber spezifischer (`IOException`/`JsonException`) wäre präziser.

**Lob:** `_lock.Release()` im `finally` (garantierte Freigabe), aussagekräftiges Debug-Log, `Math.Round(.., 6)` konsistent, sehr gute `<remarks>`-Doku der SSE-Max-Semantik. **Kein Blocker/Wichtig.**

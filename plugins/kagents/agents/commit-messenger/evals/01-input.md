# Eval-Input 01 — commit-messenger

**Aufgabe:** Generiere die Conventional-Commit-Message (erste Zeile) für die folgende Änderung.
**Original-Commit (Referenz, NICHT Teil des Modell-Inputs):** `fix(switchboard): /config endpoint auf development begrenzen (#195)` (c385f42)

```diff
diff --git a/k.switchboard.net/src/K.Switchboard/Program.cs b/k.switchboard.net/src/K.Switchboard/Program.cs
index 9d21936..8627cc9 100644
--- a/k.switchboard.net/src/K.Switchboard/Program.cs
+++ b/k.switchboard.net/src/K.Switchboard/Program.cs
@@ -88,8 +88,11 @@ try
 
     app.MapHealthChecks("/health");
 
-    app.MapGet("/config", (IOptionsSnapshot<SwitchboardOptions> opts) =>
-        TypedResults.Ok(opts.Value));
+    if (app.Environment.IsDevelopment())
+    {
+        app.MapGet("/config", (IOptionsSnapshot<SwitchboardOptions> opts) =>
+            TypedResults.Ok(opts.Value));
+    }
 
     // --- Proxy-Endpoint: POST /v1/messages ---
     app.MapPost("/v1/messages", async (HttpContext ctx, ModelRouter router, FallbackService fallback, CancellationToken ct) =>
```

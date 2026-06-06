# Eval-Input 04 — commit-messenger

**Aufgabe:** Generiere die Conventional-Commit-Message (erste Zeile) für die folgende Änderung.
**Original-Commit (Referenz, NICHT Teil des Modell-Inputs):** `fix(switchboard): falschen 200-status in fallback-fehlerpfad verhindern (#197)` (0adb376)

```diff
diff --git a/k.switchboard.net/src/K.Switchboard/Services/FallbackService.cs b/k.switchboard.net/src/K.Switchboard/Services/FallbackService.cs
index 185b5ab..0a6c617 100644
--- a/k.switchboard.net/src/K.Switchboard/Services/FallbackService.cs
+++ b/k.switchboard.net/src/K.Switchboard/Services/FallbackService.cs
@@ -32,6 +32,8 @@ public sealed class FallbackService(
         string? primaryResolvedModel = null;
         string? winnerModel = null;
         byte[]? lastCapture = null;
+        byte[]? lastFailureBody = null;
+        var lastFailureStatus = StatusCodes.Status502BadGateway;
 
         for (var i = 0; i < chain.Count; i++)
         {
@@ -51,7 +53,6 @@ public sealed class FallbackService(
             if (i > 0)
             {
                 // Fehlgeschlagene Response-State aus dem vorherigen Versuch zurücksetzen
-                context.Response.StatusCode = 200;
                 context.Response.Headers.Clear();
             }
 
@@ -90,6 +91,17 @@ public sealed class FallbackService(
             logger.LogWarning(
                 "Modell '{Model}' lieferte HTTP {Status} — {Remaining} Fallback(s) verbleiben",
                 candidate, context.Response.StatusCode, chain.Count - i - 1);
+
+            lastFailureStatus = context.Response.StatusCode;
+            lastFailureBody = lastCapture;
+        }
+
+        if (winnerModel is null)
+        {
+            context.Response.StatusCode = lastFailureStatus;
+            if (lastFailureBody is { Length: > 0 })
+                await originalBody.WriteAsync(lastFailureBody, cancellationToken);
+            return;
         }
 
         if (lastCapture is { Length: > 0 })
diff --git a/k.switchboard.net/tests/K.Switchboard.Tests/Services/FallbackServiceTests.cs b/k.switchboard.net/tests/K.Switchboard.Tests/Services/FallbackServiceTests.cs
index 4d5a83b..bc9ff41 100644
--- a/k.switchboard.net/tests/K.Switchboard.Tests/Services/FallbackServiceTests.cs
+++ b/k.switchboard.net/tests/K.Switchboard.Tests/Services/FallbackServiceTests.cs
@@ -63,13 +63,41 @@ public sealed class FallbackServiceTests
         await Assert.That(ctx.Response.Headers.ContainsKey("X-K-Switchboard-Fallback-Used")).IsFalse();
     }
 
+    [Test]
+    public async Task Forward_PrimaryFails_FallbackThrows_NoFalse200Returned()
+    {
+        var (svc, _, ctx) = Build(
+            primaryStatus: 500,
+            primaryModel: "claude-3-opus",
+            fallbacks: ["codellama:13b"],
+            fallbackThrows: true);
+
+        await svc.ForwardWithFallbackAsync(ctx, "claude-3-opus", CancellationToken.None);
+
+        await Assert.That(ctx.Response.StatusCode).IsEqualTo(500);
+        await Assert.That(ctx.Response.Headers.ContainsKey("X-K-Switchboard-Fallback-Used")).IsFalse();
+    }
+
+    [Test]
+    public async Task Forward_PrimaryThrows_NoFallbackConfigured_ReturnsBadGateway()
+    {
+        var (svc, _, ctx) = Build(primaryThrows: true, fallbacks: []);
+
+        await svc.ForwardWithFallbackAsync(ctx, "claude-3-opus", CancellationToken.None);
+
+        await Assert.That(ctx.Response.StatusCode).IsEqualTo(502);
+        await Assert.That(ctx.Response.Headers.ContainsKey("X-K-Switchboard-Fallback-Used")).IsFalse();
+    }
+
     // --- Hilfsmethoden ---
 
     private static (FallbackService Service, CostingService Costing, DefaultHttpContext Context) Build(
         int primaryStatus = 200,
         string primaryBody = "{}",
+        bool primaryThrows = false,
         int fallbackStatus = 200,
         string fallbackBody = "{}",
+        bool fallbackThrows = false,
         string primaryModel = "claude-3-opus",
         List<string>? fallbacks = null)
     {
@@ -86,10 +114,16 @@ public sealed class FallbackServiceTests
         // Stub-Provider: "anthropic" = primary, all fallback names also mapped
         var allProviders = new List<IProvider>
         {
-            new StubProvider("anthropic", primaryStatus, primaryBody)
+            primaryThrows
+                ? new ThrowingProvider("anthropic")
+                : new StubProvider("anthropic", primaryStatus, primaryBody)
         };
         if (fallbacks.Count > 0)
-            allProviders.Add(new StubProvider("ollama", fallbackStatus, fallbackBody));
+        {
+            allProviders.Add(fallbackThrows
+                ? new ThrowingProvider("ollama")
+                : new StubProvider("ollama", fallbackStatus, fallbackBody));
+        }
 
         // ModelRouter: aliases that route primary to anthropic, fallbacks to anthropic (no ':')
         var router = new ModelRouter(optsMon);
@@ -123,4 +157,13 @@ public sealed class FallbackServiceTests
             await context.Response.Body.WriteAsync(Encoding.UTF8.GetBytes(body), ct);
         }
     }
+
+    /// <summary>Test-Provider der immer eine Exception wirft.</summary>
+    private sealed class ThrowingProvider(string name) : IProvider
+    {
+        public string Name => name;
+
+        public Task ForwardAsync(HttpContext context, string resolvedModel, CancellationToken ct) =>
+            throw new HttpRequestException("Simulierter Netzwerkfehler");
+    }
 }
```

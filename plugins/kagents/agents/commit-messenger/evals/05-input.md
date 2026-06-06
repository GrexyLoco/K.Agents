# Eval-Input 05 — commit-messenger

**Aufgabe:** Generiere die Conventional-Commit-Message (erste Zeile) für die folgende Änderung.
**Original-Commit (Referenz, NICHT Teil des Modell-Inputs):** `chore(plugin): manifest-versionen auf strict semver migrieren` (2326efb)

```diff
diff --git a/.claude-plugin/marketplace.json b/.claude-plugin/marketplace.json
index 37de684..f70ab11 100644
--- a/.claude-plugin/marketplace.json
+++ b/.claude-plugin/marketplace.json
@@ -9,7 +9,7 @@
   "plugins": [
     {
       "name": "kagents",
-      "version": "v1.17.0",
+      "version": "1.18.0",
       "description": "14 spezialisierte AI-Agents und 27 Skills fuer .NET 10, C# 14, Blazor, MAUI, PowerShell Core, Azure und GitHub Actions",
       "source": "./plugins/kagents",
       "category": "development",
diff --git a/.github/plugin/marketplace.json b/.github/plugin/marketplace.json
index 6f2013b..33afbc8 100644
--- a/.github/plugin/marketplace.json
+++ b/.github/plugin/marketplace.json
@@ -6,13 +6,13 @@
   },
   "metadata": {
     "description": "14 spezialisierte AI-Agents und 27 Skills für .NET 10, C# 14, Blazor, MAUI, PowerShell Core, GitHub Actions und Azure.",
-    "version": "v1.17.0"
+    "version": "1.18.0"
   },
   "plugins": [
     {
       "name": "kagents",
       "description": "14 spezialisierte AI-Agents und 27 Skills fuer .NET, PowerShell und Azure",
-      "version": "v1.17.0",
+      "version": "1.18.0",
       "source": "./plugins/kagents"
     }
   ]
diff --git a/plugins/kagents/.claude-plugin/plugin.json b/plugins/kagents/.claude-plugin/plugin.json
index c762a91..d7a7151 100644
--- a/plugins/kagents/.claude-plugin/plugin.json
+++ b/plugins/kagents/.claude-plugin/plugin.json
@@ -1,7 +1,7 @@
 {
   "name": "kagents",
   "description": "15 spezialisierte AI-Agents und 46 Skills für .NET 10, C# 14, Blazor, MAUI, PowerShell Core, Azure und GitHub Actions",
-  "version": "v1.14.0",
+  "version": "1.18.0",
   "author": {
     "name": "GrexyLoco",
     "email": "noreply@grexyloco.dev"
diff --git a/plugins/kagents/.github/plugin/plugin.json b/plugins/kagents/.github/plugin/plugin.json
index 2c78528..e113358 100644
--- a/plugins/kagents/.github/plugin/plugin.json
+++ b/plugins/kagents/.github/plugin/plugin.json
@@ -1,7 +1,7 @@
 {
   "name": "kagents",
   "description": "15 spezialisierte AI-Agents und 37 Skills fuer .NET 10, C# 14, Blazor, MAUI, PowerShell Core, GitHub Actions und Azure.",
-  "version": "v1.17.0",
+  "version": "1.18.0",
   "author": {
     "name": "GrexyLoco",
     "email": "noreply@grexyloco.dev"
```

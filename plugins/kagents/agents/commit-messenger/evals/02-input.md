# Eval-Input 02 — commit-messenger

**Aufgabe:** Generiere die Conventional-Commit-Message (erste Zeile) für die folgende Änderung.
**Original-Commit (Referenz, NICHT Teil des Modell-Inputs):** `fix(ci): release-asset-upload nur fuer stable-tags` (4f21e65)

```diff
diff --git a/.github/workflows/k-switchboard-net-ci.yml b/.github/workflows/k-switchboard-net-ci.yml
index c0b647a..f1bf7ce 100644
--- a/.github/workflows/k-switchboard-net-ci.yml
+++ b/.github/workflows/k-switchboard-net-ci.yml
@@ -102,7 +102,10 @@ jobs:
   upload-release-asset:
     name: Bundle + README an GitHub Release anhängen
     needs: build-test-publish
-    if: startsWith(github.ref, 'refs/tags/v')
+    # Nur fuer Stable-Tags (vX.Y.Z) hochladen — Pre-Release-Tags wie
+    # v1.18.1-freeze/-beta/-alpha haben kein GitHub Release und wuerden
+    # mit "release not found" fehlschlagen.
+    if: startsWith(github.ref, 'refs/tags/v') && !contains(github.ref_name, '-')
     runs-on: windows-latest
 
     permissions:
```

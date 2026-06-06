# Claude-Baseline 04

```text
fix(switchboard): korrekten Fehlerstatus statt 200 im Fallback liefern
```

**Begründung:** `type=fix` (falscher 200-Status im Fehlerpfad behoben), `scope=switchboard` (FallbackService), Imperativ „liefern", 70 Zeichen. Tests gehören zum selben Fix — kein eigener `test`-Commit.

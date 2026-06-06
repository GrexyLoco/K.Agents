# Ergebnisse — commit-messenger Quality-Eval (Spike #251)

**Datum:** 2026-06-06 · **Hardware:** CPU-only · **Methode:** direkter Ollama-Call (`stream:false`), kein Proxy.

## Go/No-Go: ❌ NO-GO — commit-messenger bei Claude belassen

**Kein** getestetes lokales Modell (`qwen2.5-coder:1.5b`, `llama3.2:3b`, `qwen2.5-coder:7b`) erreicht das #248-Kriterium **≥ 70 % A/B**. Alle drei liegen bei **0 % A/B**. Selbst das größte (7b) löst die Kernprobleme nicht — und kostet bereits bis 62 s Latenz.

## Score-Tabelle (A = gleichwertig · B = produktiv · C = Notfall · F = unbrauchbar)

| # | Typ/Scope (Soll) | `1.5b` | `3b` | `7b` |
|---|---|:---:|:---:|:---:|
| 01 | fix/switchboard (`/config` nur Dev) | F | C | C |
| 02 | fix/ci (Asset-Upload nur Stable) | C | C | C |
| 03 | docs/install (Duplikat-Schutz) | C | C | C |
| 04 | fix/switchboard (kein falscher 200) | F | F | F |
| 05 | chore/plugin (SemVer-Migration) | F | F | F |
| **A/B-Quote** | | **0 %** | **0 %** | **0 %** |

## Latenz (CPU-only, Sekunden)

| # | Input-Tokens | `1.5b` | `3b` | `7b` |
|---|---:|---:|---:|---:|
| 01 | ~460 | 11.9 | 18.3 | 41.7 |
| 02 | ~470 | 3.1 | 5.4 | 12.7 |
| 03 | ~1020 | 7.4 | 15.7 | 34.8 |
| 04 | ~1500 | 11.6 | 25.3 | **62.4** |
| 05 | ~1050 | 7.6 | 15.8 | 33.3 |

Latenz ist für die kleinen Modelle unkritisch (< 30 s); 7b nähert sich bei größeren Diffs dem 100 s-Budget (#252).

## Wiederkehrende Fehlerklassen (alle Modelle)

1. **Falscher `type`** — fast durchgängig `feat`/`refactor` statt korrektem `fix`/`docs`/`chore`. Genau die Kernkompetenz des Agents wird verfehlt.
2. **`scope` = Dateipfad** statt Konventions-Scope (`k.switchboard.net/src/.../Program.cs` statt `switchboard`).
3. **Halluzinationen** — erfundene Issue-Refs (`#42`) und Versionen (`v1.18.0`), die nicht im Diff stehen.
4. **Sprach-Drift** — 1.5b und 7b mischen Englisch ein, trotz Deutsch-Vorgabe.
5. **Zweck verfehlt** — Beschreibungen geben Implementierungsdetails (`Hinzufügen von lastFailureBody`) statt der Aussage (`korrekten Fehlerstatus liefern`); Input 04 (mit Tests) reißt alle Modelle auf F.
6. **Regelverstöße** — 7b erzeugt bei 04 **zwei** Messages (statt „genau eine"); kaputte Scopes (`marketplace.json, !`).

## Rückmeldung an #248

- **Die geplante Migration `commit-messenger → llama3.2:3b` ist NICHT tragfähig.** 3b liefert 0 % A/B; das schnellere 1.5b ebenso; selbst 7b (größer als geplant) scheitert.
- **Empfehlung:** `commit-messenger` **bei Claude (Haiku) belassen.** Conventional-Commit-Disziplin (präziser Typ, Konventions-Scope, keine Halluzination) ist für ≤ 7B-Modelle auf dieser Hardware nicht erreichbar.
- **Wenn lokale Migration trotzdem gewünscht:** nur mit deutlich größeren Modellen (≥ 14B) und striktem, mit Beispielen angereichertem Prompt erneut testen — bei fraglichem ROI (7b schon 62 s).
- **Konsequenz für den #248-Ansatz:** Die Grundannahme „lokale Modelle ≤ 14B liefern akzeptable Qualität" trifft für den **format-disziplinierten** Tier-S-Agent **nicht** zu. Der gegenteilige Endpunkt (`code-reviewer`, Tier L, eher Verständnis- als Format-Aufgabe) ist separat zu prüfen — dort kann das Bild anders ausfallen.

> **Scoring-Hinweis:** Erst-Bewertung durch Claude. Bitte stichprobenartig gegen die Roh-Outputs in `runs/2026-06-06/` validieren — die Tendenz (0 % A/B) ist allerdings eindeutig und nicht grenzwertig.

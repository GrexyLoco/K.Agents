# Ergebnisse — code-reviewer Quality-Eval (Spike #251)

**Datum:** 2026-06-06 · **Hardware:** 15,4 GB RAM, CPU-only · **Methode:** direkter Ollama-Call.

## Go/No-Go: ❌ NO-GO — code-reviewer bei Claude (Opus) belassen

`qwen2.5-coder:7b` erreicht **0 % A/B** und liefert teils **aktiv schädliche** Reviews (Halluzinationen, Empfehlungen, die guten Code verschlechtern). `qwen2.5-coder:14b` ist auf dieser Hardware **nicht testbar** (RAM, s. u.).

## Hardware-Limit (eigener Befund)

| Modell | Größe | Status |
|---|---|---|
| `qwen2.5-coder:7b` | 5,9 GB | getestet, aber **unzuverlässig** (Cold-Load + 2/5 Timeouts) |
| `qwen2.5-coder:14b` | 9,0 GB | **N/A** — 14b + 7b + IDE (Rider ~2,7 GB) sprengen die 15,4 GB RAM → Swapping, Ollama hängt im „Stopping..." |

➡️ Auf einer 15-GB-Workstation mit laufender IDE ist 14b **kein Kandidat** — unabhängig von Qualität.

## Score-Tabelle (A = gleichwertig · B = produktiv · C = Notfall · F = unbrauchbar)

| # | Code (Soll-Findings) | `7b` | Anmerkung |
|---|---|:--:|---|
| 01 | ModelRouter (`:`-Heuristik) | ⏱️ Timeout | Cold-Load, 1800 s abgebrochen |
| 02 | AnthropicProvider | **F** | halluziniert „`logger`/`ct` ungenutzt" (beide falsch), 3× Wiederholung, kaputte Zeichen |
| 03 | CostingService | **C** | 1 Treffer (breiter catch) + Magic-Number; aber „TryExtractUsage ist async" (falsch, ist `static bool`), Hauptpunkte verfehlt |
| 04 | OllamaProvider (`GetValue<T>`-Throw) | ⏱️ Timeout | der **substanziellste** Test (echtes Throw-Risiko) — nicht abgeschlossen |
| 05 | install-windows.ps1 (PS) | **F** | reviewt `Install-Portable` (**nicht im Ausschnitt** → Halluzination), empfiehlt Approved-Verb-**Verletzungen**, falsche `$PSScriptRoot`-Behauptung |
| **A/B-Quote (abgeschlossen)** | | **0 %** | (1×C, 2×F von 3) |

## Latenz/Zuverlässigkeit (7b, CPU-only)

| # | Input→Output-Tokens | Latenz |
|---|---|---:|
| 02 | 995→443 | 114 s |
| 03 | 1110→761 | 179 s |
| 05 | 983→1351 | 302 s |
| 01, 04 | — | **Timeout (1800 s)** |

Selbst wenn es läuft: 114–302 s/Review (über 100 s-Budget; für Read-only laut #251 tolerierbar). **Aber 2/5 Reviews brechen ab** — produktiv unbrauchbar.

## Fehlerklassen (7b)

1. **Halluzinationen (False Positives)** — behauptet ungenutzte Parameter (`logger`, `ct`), die nachweislich genutzt werden; „async"-Methode, die `static` ist; reviewt Code (`Install-Portable`), der gar nicht im Ausschnitt steht.
2. **Aktiv schädliche Empfehlungen** — schlägt PowerShell-Namen vor, die **Approved Verbs verletzen** (`CreateFileSystemAccessRuleForNetworkService` statt `New-…`) → würde guten Code verschlechtern.
3. **Niedriger Recall** — die echten Baseline-Findings (insb. das `GetValue<T>`-Throw-Risiko in 04) werden nicht erkannt (04 lief gar nicht durch).
4. **Repetitions-Schleifen** — identische Findings 2–3× wiederholt (typisch für kleine Modelle bei langem Output).
5. **Encoding-Artefakte** — gemischte CJK-Zeichen im deutschen Text.

## Rückmeldung an #248

- **`code-reviewer → qwen2.5-coder:14b` (geplant) ist auf dieser Hardware nicht umsetzbar** (RAM) und auf besserer Hardware fraglich — der kleinere, lauffähige 7b liefert **0 % A/B** mit halluzinierten/schädlichen Findings.
- **Empfehlung:** `code-reviewer` **bei Claude (Opus) belassen.** Ein Reviewer, der Probleme *erfindet* und *schlechtere* Lösungen vorschlägt, ist gefährlicher als keiner.
- **Gesamt-Fazit des Spikes (beide Endpunkte):** Die #248-Grundannahme „lokale Modelle ≤ 14B liefern akzeptable Qualität" ist **für beide Spektrum-Enden widerlegt** — der format-disziplinierte `commit-messenger` (Tier S, 0 % A/B) *und* der verständnis-orientierte `code-reviewer` (Tier L, 0 % A/B). Für Phase 1 wird **keine** der vier geplanten Migrationen empfohlen, solange keine deutlich stärkeren lokalen Modelle + passende Hardware (≥ 32 GB RAM, idealerweise GPU) verfügbar sind.

> **Scoring-Hinweis:** Erst-Bewertung durch Claude gegen die Baselines in `*-claude-baseline.md`. 01/04 fehlen (Timeout) — der GetValue-Throw-Test (04) wäre der härteste gewesen; das Bild der übrigen ist aber eindeutig.

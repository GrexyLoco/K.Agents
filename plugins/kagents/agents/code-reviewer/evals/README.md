# code-reviewer — Quality-Evals (Spike #251)

Validiert, ob lokale Ollama-Modelle für den `code-reviewer`-Agent (Tier L, höchstes Risiko) brauchbare Reviews liefern. Gegenstück zum `commit-messenger` (Tier S) — die beiden Spektrum-Enden aus #251.

## Aufbau

| Datei | Zweck |
| --- | --- |
| `NN-input.md` | Realer Code-Ausschnitt aus `k.switchboard.net/src/` (C#) bzw. `scripts/` (PS) + Review-Aufgabe |
| `NN-claude-baseline.md` | Referenz-Findings (Claude) je Ausschnitt, mit Severity |
| `run-evals.ps1` | Schickt Aufgabe + Code + code-reviewer-System-Prompt **direkt an Ollama** (kein Proxy), `TimeoutSec` hoch (14b ist langsam) |
| `runs/<datum>/code-reviewer-<modell>.md` | Roh-Reviews je Modell |
| `results.md` | Bewertung (Recall/Precision/Severity/Format) + Go/No-Go |

## Methodik (anders als commit-messenger)

Code-Review ist eine **Verständnis-** statt **Format-Aufgabe**. Bewertet wird nicht „trifft eine exakte Zielzeichenkette", sondern:

- **Recall** — werden die echten Baseline-Findings gefunden? (insb. der Throw-Risiko-Punkt in Fixture 04)
- **Precision** — werden **erfundene** Probleme behauptet (Halluzination)?
- **Severity-Genauigkeit** — plausible Einstufung (Blocker/Wichtig/Verbesserung/Hinweis)?
- **Format & Sprache** — konstruktiv, Datei:Zeile + Empfehlung, Deutsch?

5 Ausschnitte unterschiedlicher Substanz: 01 ModelRouter (klein/sauber), 02 AnthropicProvider (Passthrough), 03 CostingService (IO/Aggregation), 04 OllamaProvider (echtes `GetValue<T>`-Throw-Risiko), 05 install-windows.ps1 (PowerShell).

## Re-Run

```powershell
./run-evals.ps1 -Models 'qwen2.5-coder:7b'
./run-evals.ps1 -Models 'qwen2.5-coder:14b' -TimeoutSec 2400
```

> Modelle **einzeln** übergeben — eine Komma-Liste über `pwsh -File` wird falsch als ein String geparst.

Siehe `results.md` für Scores und Empfehlung.

# commit-messenger — Quality-Evals (Spike #251)

Validiert, ob lokale Ollama-Modelle für den `commit-messenger`-Agent das #248-Akzeptanzkriterium (**≥ 70 % der Inputs mit Score A oder B** gegenüber Claude-Baseline) erreichen.

## Aufbau

| Datei | Zweck |
| --- | --- |
| `NN-input.md` | Realer git-Diff (ohne Original-Message) als Eval-Input |
| `NN-claude-baseline.md` | Ideale Conventional-Commit-Message (Claude = Referenz) |
| `run-evals.ps1` | Schickt jeden Diff + den commit-messenger-System-Prompt **direkt an Ollama** (`localhost:11434`, kein Proxy → nicht vom #252-Timeout betroffen), protokolliert Output + Latenz |
| `runs/<datum>/commit-messenger-<modell>.md` | Roh-Outputs je Modell |
| `results.md` | Score-Tabelle (A/B/C/F) + Latenz + Go/No-Go |

## Methodik

- **5 reale Inputs** aus der Repo-Historie, bewusst typ-/scope-divers (fix-Code, fix-CI, docs, fix-Code+Tests, chore-Manifest).
- **System-Prompt** = `commit-messenger.agent.md` (Format + Regeln), damit der echte Agent getestet wird.
- **Score-Skala (aus #248):** A = gleichwertig · B = akzeptabel/produktiv · C = schlechter, Notfall · F = unbrauchbar.
- **Scoring** durch Claude als Erst-Reviewer; finale Bestätigung durch den PO.

## Re-Run

```powershell
./run-evals.ps1                                   # Default: 1.5b + 3b
./run-evals.ps1 -Models 'qwen2.5-coder:7b'        # einzelnes Modell
```

Siehe `results.md` für Scores und Empfehlung.

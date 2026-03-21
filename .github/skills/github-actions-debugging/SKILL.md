---
name: github-actions-debugging
description: GitHub Actions Workflow-Run Analyse und Debugging. Nutze diesen Skill zum Analysieren fehlgeschlagener Workflows und Performance-Probleme.
---

# GitHub Actions Debugging

## Failed Run analysieren

### Log-Analyse
1. Run-ID ermitteln: `gh run list --status failure --limit 5`
2. Logs herunterladen: `gh run view <RUN_ID> --log-failed`
3. Fehler-Pattern suchen: Exit-Codes, Exception-Messages, Timeouts

### Häufige Fehler-Patterns
| Symptom | Wahrscheinliche Ursache |
|---------|------------------------|
| `Process completed with exit code 1` | Test/Build-Fehler im Code |
| `Error: Resource not accessible` | Fehlende Permissions im Workflow |
| `Error: HttpError: rate limit exceeded` | API Rate Limiting |
| `The runner has received a shutdown signal` | Timeout oder Cancellation |
| `No space left on device` | Artefakte/Cache zu groß |

### Matrix-Failure isolieren
```bash
# Welche Matrix-Kombination ist betroffen?
gh run view <RUN_ID> --json jobs --jq '.jobs[] | select(.conclusion=="failure") | .name'
```

## Performance-Analyse
- Job-Durations vergleichen: `gh run view <RUN_ID> --json jobs --jq '.jobs[] | {name, duration: (.completedAt | fromdate) - (.startedAt | fromdate)}'`
- Cache Hit Rate prüfen: `Post actions/cache` Step in Logs
- Parallelisierung: Sind unabhängige Jobs sequentiell?

## Debugging-Tipps
- Re-Run mit Debug-Logs: Repository Secret `ACTIONS_STEP_DEBUG=true`
- Einzelnen Job re-runnen: `gh run rerun <RUN_ID> --job <JOB_ID>`
- SSH-Zugang zum Runner: `mxschmitt/action-tmate` (nur für Debugging)

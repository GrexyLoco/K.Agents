---
name: github-actions-debugging
description: "GitHub Actions debugging — failed workflow analysis, error pattern diagnosis (exit codes, permissions, rate limiting, timeouts), log downloading, matrix failure isolation, gh CLI, debug re-runs. USE FOR: analyzing why a workflow run failed, diagnosing CI performance issues, reading workflow logs. DO NOT USE FOR: creating new workflows or actions (use github-actions-patterns)."
---

# 1. GitHub Actions Debugging

## 1.1 Failed Run analysieren

### 1.1.1 Log-Analyse
1. Run-ID ermitteln: `gh run list --status failure --limit 5`
2. Logs herunterladen: `gh run view <RUN_ID> --log-failed`
3. Fehler-Pattern suchen: Exit-Codes, Exception-Messages, Timeouts

### 1.1.2 Häufige Fehler-Patterns
| Symptom | Wahrscheinliche Ursache |
|---------|------------------------|
| `Process completed with exit code 1` | Test/Build-Fehler im Code |
| `Error: Resource not accessible` | Fehlende Permissions im Workflow |
| `Error: HttpError: rate limit exceeded` | API Rate Limiting |
| `The runner has received a shutdown signal` | Timeout oder Cancellation |
| `No space left on device` | Artefakte/Cache zu groß |

### 1.1.3 Matrix-Failure isolieren
```bash
# Welche Matrix-Kombination ist betroffen?
gh run view <RUN_ID> --json jobs --jq '.jobs[] | select(.conclusion=="failure") | .name'
```

## 1.2 Performance-Analyse
- Job-Durations vergleichen: `gh run view <RUN_ID> --json jobs --jq '.jobs[] | {name, duration: (.completedAt | fromdate) - (.startedAt | fromdate)}'`
- Cache Hit Rate prüfen: `Post actions/cache` Step in Logs
- Parallelisierung: Sind unabhängige Jobs sequentiell?

## 1.3 Debugging-Tipps
- Re-Run mit Debug-Logs: Repository Secret `ACTIONS_STEP_DEBUG=true`
- Einzelnen Job re-runnen: `gh run rerun <RUN_ID> --job <JOB_ID>`
- SSH-Zugang zum Runner: `mxschmitt/action-tmate` (nur für Debugging)

---
name: github-actions-patterns
description: GitHub Actions workflow patterns and best practices. Use this skill for creating, optimizing, and debugging CI/CD workflows. Includes patterns from the K.Actions.ReleaseFlow project.

# GitHub Actions Patterns

## Reusable + Direct Trigger Pattern (Quality Gate Stil)
```yaml
# Kann als workflow_call UND direkt als pull_request genutzt werden
on:
  pull_request:
    branches: [master, main, 'dev/v*', 'release/v*']
    paths-ignore: ['**/*.md', 'examples/**']
  workflow_call:
    outputs:
      quality-success:
        description: "Quality Gate bestanden"
        value: ${{ jobs.quality-gate.outputs.quality-success }}
```

## GitHub App Token (statt PAT)
```yaml
- name: Generate App Token
  id: app-token
  uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ vars.RELEASEFLOW_APP_ID }}
    private-key: ${{ secrets.RELEASEFLOW_APP_PRIVATE_KEY }}

- uses: actions/checkout@v4
  with:
    fetch-depth: 0
    fetch-tags: true
    token: ${{ steps.app-token.outputs.token }}
```

**Warum App Token statt PAT:**
- Scoped Permissions pro Repo
- Audit Trail als Bot-Identity
- Ruleset Bypass als Integration-Actor
- Downstream-Trigger für `on: push` Workflows
- Kein Risiko bei Mitarbeiterwechsel

## Quality Gate Pipeline-Muster
```yaml
jobs:
  quality-gate:
    runs-on: ${{ vars.UBUNTU_VERSION || 'ubuntu-24.04' }}
    outputs:
      quality-success: ${{ steps.evaluate.outputs.quality-success }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      # 1. Security (GitLeaks)
      # 2. Strukturvalidierung
      # 3. Lint (PSScriptAnalyzer)
      # 4. Tests (Pester)
      # 5. Evaluation (aggregiert)
      # 6. Summary

  release:
    needs: quality-gate
    if: needs.quality-gate.outputs.quality-success == 'true'
    # ...
```

## Runner-Version konfigurierbar
```yaml
runs-on: ${{ vars.UBUNTU_VERSION || 'ubuntu-24.04' }}
```

## Permissions (Least-Privilege)
```yaml
permissions:
  contents: read
  actions: read
  pull-requests: read
```
Nur `write` vergeben wenn der Job tatsächlich schreibt (Tags, PRs, Commits).

## PowerShell in Actions
```yaml
- name: Run Script
  shell: pwsh   # NICHT 'powershell'!
  run: |
    $ErrorActionPreference = 'Stop'
    & "./.github/scripts/Run-PesterTests.ps1"
```

## CI-Scripts auslagern (.github/scripts/)
Komplexe Logik gehört nicht inline ins YAML — auslagern in `.github/scripts/`:
```yaml
- name: Quality Gate auswerten
  shell: pwsh
  run: |
    & "./.github/scripts/Invoke-QualityGateEvaluation.ps1" `
      -GitLeaksOutcome '${{ steps.gitleaks.outcome }}' `
      -LintSuccess     '${{ steps.lint.outputs.analysis-success }}'
```

## Outputs aus PowerShell setzen
```powershell
if ($env:GITHUB_OUTPUT) {
    "quality-success=true" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
}
```

## Conditional Jobs mit Source-Branch-Filter
```yaml
release:
  if: |
    (
      github.event.pull_request.merged == true &&
      startsWith(github.head_ref, 'release/v')
    ) || github.event_name == 'workflow_dispatch'
```

## Badge-Updates als separater Job
```yaml
update-badges:
  needs: [quality-gate, release]
  if: always()  # Auch bei Release-Fehler Badges aktualisieren
  continue-on-error: true  # Darf Pipeline nicht blockieren
```

## Matrix Build
```yaml
strategy:
  matrix:
    os: [ubuntu-latest, windows-latest, macos-latest]
  fail-fast: false
runs-on: ${{ matrix.os }}
```

## Caching
```yaml
- uses: actions/cache@v4
  with:
    path: ~/.nuget/packages
    key: ${{ runner.os }}-nuget-${{ hashFiles('**/*.csproj') }}
    restore-keys: ${{ runner.os }}-nuget-
```

## Security
- Actions auf SHA pinnen (nicht nur Tag)
- `permissions:` Block immer explizit setzen
- Secrets nie in Logs: `::add-mask::${{ secrets.TOKEN }}`
- Keine `pull_request_target` mit Checkout des PR-Branches
- GitLeaks als erster CI-Step

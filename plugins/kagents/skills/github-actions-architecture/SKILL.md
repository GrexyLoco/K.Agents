---
name: github-actions-architecture
description: GitHub Actions Architecture — Reusable Workflows, Composite Actions, Matrix-Builds, Caching-Strategien, Concurrency-Gruppen. USE FOR: architecting scalable CI/CD pipelines, optimizing build performance, managing secrets securely. DO NOT USE FOR: debugging failing workflows (use github-actions-debugging) or security scanning (use github-actions-security).
---

# 1. GitHub Actions Architecture

## 1.1 Reusable Workflows vs. Composite Actions

| Aspekt | Reusable Workflow | Composite Action |
|--------|------------------|-----------------|
| Scope | Entire workflow (multiple jobs) | Single job / step level |
| Triggers | ✓ push, pull_request, release, schedule | ✗ No direct triggers |
| Matrix Support | ✓ Full matrix-build support | ✗ Limited (only outputs) |
| Reuse Complexity | Medium (call via `uses`) | Low (inline in step) |
| Secret Access | ✓ Via `secrets:` context | ✗ Must pass explicitly |
| State Management | ✓ Outputs, artifacts | ✓ Outputs only |

**Use Reusable Workflows for:** Multi-job release/deployment pipelines, matrix-based testing across platforms.  
**Use Composite Actions for:** Utility steps (setup, build, report), reducing duplication in single jobs.

## 1.2 Matrix-Builds

```yaml
strategy:
  matrix:
    os: [ubuntu-latest, windows-latest, macos-latest]
    dotnet-version: ['8.0', '9.0']
  fail-fast: false

steps:
  - uses: actions/setup-dotnet@v4
    with:
      dotnet-version: ${{ matrix.dotnet-version }}
  - run: dotnet test --configuration Release
```

**Include:** OS (ubuntu, windows, macos), .NET versions, architecture targets (x64, arm64).  
**Exclude:** Windows + macOS-only targets via `exclude` or conditional `if: runner.os == 'Linux'`.

## 1.3 Caching Strategies

```yaml
- name: Cache NuGet packages
  uses: actions/cache@v4
  with:
    path: ~/.nuget/packages
    key: ${{ runner.os }}-nuget-${{ hashFiles('**/*.csproj') }}
    restore-keys: |
      ${{ runner.os }}-nuget-

- name: Cache build artifacts
  uses: actions/cache@v4
  with:
    path: bin/Release
    key: ${{ runner.os }}-build-${{ github.sha }}
```

**Cache keys:** Hash on lock files (`*.csproj`, `global.json`, `package-lock.json`).  
**Restore keys:** Enable fallback to recent caches if exact match fails.  
**Limits:** 5GB per repo; oldest entries evicted first.

## 1.4 Workflow-Trigger Design

- **push:** On every commit to tracked branches (feature/*, hotfix/*).
- **pull_request:** On PR creation/update; avoid secrets in untrusted forks.
- **release:** Triggered by GitHub Release publish; optimal for artifact uploads.
- **schedule:** Cron-based nightly/weekly tests (UTC timezone).
- **workflow_dispatch:** Manual trigger with input parameters.

```yaml
on:
  push:
    branches: [main, develop]
    paths: ['src/**', '.github/workflows/**']
  pull_request:
    types: [opened, synchronize, reopened]
  release:
    types: [published]
```

## 1.5 Secret Management

**Use GitHub App Token** (via `GITHUB_TOKEN`) for actions; auto-rotated per run.  
**Use OIDC** for cloud credentials (AWS, Azure); eliminates long-lived tokens.  
**Never use Personal Access Tokens** in workflows; use Secrets instead.

```yaml
- name: Authenticate with Azure
  uses: azure/login@v2
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

Secrets are redacted in logs; use `run: echo ${{ secrets.MY_SECRET }}` only for verification.

## 1.6 Workflow Concurrency

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

**Concurrency Group:** Identifies uniqueness (workflow + branch, or workflow + PR number).  
**cancel-in-progress:** Cancels older runs on same group; prevents stale deployments.  
**Use for:** Release pipelines, production deployments (ensure only latest runs).

---

**Key Rules:**  
- Prefer Reusable Workflows for multi-job orchestration.  
- Cache aggressively; hash on dependency files.  
- Use OIDC/App Tokens; avoid PATs.  
- Set concurrency groups for deploy jobs.

---
name: github-actions-security
description: "GitHub Actions Security — secret masking, OIDC, minimal permissions, SHA pinning, environment protection. USE FOR: securing secrets, OIDC, permissions, pinning. DO NOT USE FOR: debugging (github-actions-debugging) or patterns (github-actions-patterns)."
---

# GitHub Actions Security

## Secrets: Masking & Environments

### Auto-Masking
```yaml
jobs:
  deploy:
    steps:
      - env:
          API_KEY: ${{ secrets.API_KEY }}
        run: curl -H "Bearer $API_KEY" https://api.example.com
# Any secret value automatically masked as ***
```

### Manual Masking & Production Secrets
```yaml
- run: echo "::add-mask::custom-secret"

deploy-prod:
  environment: production  # Scoped secrets + protection rules
  steps:
    - run: echo ${{ secrets.PROD_API_KEY }}
```

## Actions: SHA Pinning

```yaml
# ❌ BAD: Tag can be re-pointed
- uses: actions/checkout@v4

# ✅ GOOD: SHA is immutable
- uses: actions/checkout@a81bbbf8298c0fa03ea29cdc473d45aa312e3d37

# Find SHAs: gh api repos/owner/action/git/refs/tags/v4.0.0 --jq '.object.sha'
```

## Permissions: Least-Privilege

### Workflow Level
```yaml
permissions:
  contents: read
  pull-requests: read
  checks: write
```

### Job Level Override
```yaml
jobs:
  write-pr:
    permissions:
      pull-requests: write  # Only this job
```

Avoid: `contents: write` + `pull-requests: write` = modify + approve

## OIDC Authentication

### Why OIDC Over PATs
- Expiration: 15 min (vs. PAT: unbounded)
- Scope: Per repo (vs. PAT: global)
- Audit: GitHub Action identity

### AWS & Azure
```yaml
permissions:
  id-token: write
jobs:
  deploy:
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::ACCOUNT:role/GitHubActionsRole
      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
```

## Environment Protection Rules

Settings → Environments → [name]:
- **Branches:** `main`, `release/*` only
- **Reviewers:** 1–5 approvals
- **Wait:** 0–30 min before deploy

```yaml
deploy-prod:
  environment:
    name: production
    url: https://prod.example.com
  steps:
    - run: ./deploy.sh
```

## Checklist

- Secrets auto-masked
- Actions pinned to SHA
- Minimal `permissions:`
- OIDC for cloud (not PATs)
- Production protected
- No hardcoded secrets

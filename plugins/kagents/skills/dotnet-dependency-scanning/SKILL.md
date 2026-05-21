---
name: dotnet-dependency-scanning
description: ".NET Dependency Scanning — dotnet audit, CVE analysis, GitHub Advisory Database integration, vulnerable package detection, security patch recommendations. USE FOR: scanning dependencies for vulnerabilities, analyzing CVE severity and exploitability, recommending security patches. DO NOT USE FOR: general dependency updates (use dotnet-build-diagnosis) or dependency architecture review (use app-architecture)."
---

# 1. .NET Dependency Scanning

## 1.1 Vulnerability Detection

### 1.1.1 dotnet list package (Vulnerable)
```bash
# Direct dependencies
dotnet list package --vulnerable

# Include transitive dependencies
dotnet list package --vulnerable --include-transitive

# For specific project
dotnet list ./src/MyApp/MyApp.csproj package --vulnerable
```

### 1.1.2 dotnet audit
```bash
# Audit all vulnerabilities
dotnet audit

# Exit with code on vulnerabilities (CI-safe)
dotnet audit --exit-code 1

# List all vulnerabilities with details
dotnet audit --verbose

# Export to JSON (for tooling)
dotnet audit --format json > audit-results.json
```

## 1.2 CVE Analysis

### 1.2.1 Critical CVE Fields
| Field | Purpose | Example |
|-------|---------|---------|
| CVE-ID | Unique identifier | CVE-2024-12345 |
| CVSS Score | Severity (0–10) | 8.9 (High) |
| Affected Version | Version range | < 2.0.5 |
| Fixed Version | Patch version | >= 2.0.5 |
| Exploitability | Practical risk | Proof-of-concept available |
| Workaround | Mitigation if unfixed | Disable feature X |

### 1.2.2 CVE Severity Classification
- **Critical (9.0–10.0)**: Immediate patching required
- **High (7.0–8.9)**: Patch within days, escalate to team
- **Medium (4.0–6.9)**: Schedule patch in next cycle
- **Low (0.1–3.9)**: Monitor, patch opportunistically

## 1.3 GitHub Advisory Database

### 1.3.1 Integration with dotnet audit
- **Source**: GitHub Security Advisories (https://github.com/advisories)
- **Updated**: Feeds into dotnet audit automatically
- **Format**: NVD + Microsoft Security Response Center (MSRC)

### 1.3.2 Advisory Lookup
```bash
# View specific package advisory history
# Visit: https://github.com/advisories?query=Package%3A<PackageName>

# Example for Newtonsoft.Json
# https://github.com/advisories?query=Package%3ANewtonsoft.Json
```

### 1.3.3 Remediation Workflow
1. **Detect**: Run `dotnet audit`
2. **Classify**: Group by CVSS score and fixability
3. **Patch**: Update to fixed version (or supported workaround)
4. **Verify**: Re-run audit to confirm
5. **Document**: Track remediation in PR/changelog

## 1.4 Best Practices

- **Frequent Audits**: Run `dotnet audit` in CI (pre-commit or PR)
- **Transitive Deps**: Always include `--include-transitive` — transitive vulnerabilities are as critical
- **Zero-Day Handling**: GitHub Advisories updated within 24h; subscribe to repo security alerts
- **Workarounds**: Document if patch unavailable (temporary mitigation)
- **Automation**: Dependabot + dotnet audit = automatic patch PRs

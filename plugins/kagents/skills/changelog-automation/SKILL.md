---
name: changelog-automation
description: "Changelog-Automatisierung — Changelog aus Commits generieren, Keep-a-Changelog Format, Commit-Kategorisierung (feat → Added, fix → Fixed, perf → Improved, refactor → Changed). Breaking Changes mit `!` oder BREAKING CHANGE-Footer. USE FOR: generating changelogs from Conventional Commits, extracting issue references, structuring release notes. DO NOT USE FOR: commit format validation (use conventional-commits) or release process management (use release-management)."
---

# 1. Changelog Automation

## 1.1 Generate from Conventional Commits

Filter commits by type to populate changelog sections:

```bash
# Extract features (feat) since last tag
git log v1.12.0..HEAD --grep='^feat' --oneline

# Extract fixes (fix, perf)
git log v1.12.0..HEAD --grep='^fix\|^perf' --oneline

# All changed (refactor, deps, etc.)
git log v1.12.0..HEAD --grep='^refactor\|^chore' --oneline
```

## 1.2 Keep-a-Changelog Format

Standard sections per version:

```markdown
## [1.13.0] — 2026-04-29

### Breaking Changes
- API response format changed: `status` field renamed to `state`

### Added
- New `changelog-automation` skill for generating changelogs
- Git log filtering by commit type

### Fixed
- Race condition in Alpha/Beta release workflow

### Changed
- Simplified Keep-a-Changelog structure
```

## 1.3 Commit Categorization

Map conventional commit types to changelog sections:

| Commit Type | Changelog Section | Example |
|-------------|-------------------|---------|
| `feat` | **Added** | New feature or capability |
| `fix` | **Fixed** | Bug fix |
| `perf` | **Improved** | Performance enhancement |
| `refactor` | **Changed** | Code restructuring |
| `docs` | — | Skip (or optional **Documentation**) |
| `chore` | — | Skip |

## 1.4 Breaking Changes

Extract from commit messages with `!` or `BREAKING CHANGE` footer:

```
feat(api)!: Change response format

BREAKING CHANGE: The 'status' field is now 'state'. Migration: update client code.
```

Place breaking changes at the top of the version section.

## 1.5 Link Issue References

Extract issue numbers from commit bodies and link to pull requests:

```bash
# Extract #123 pattern
git log --oneline | grep -oE '#[0-9]+'
```

Format: `[#84](https://github.com/GrexyLoco/K.Agents/issues/84)`

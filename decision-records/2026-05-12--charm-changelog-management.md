**Date:** 2026-05-12  
**Author:** Luca Bello

## Decision

Each charm repository maintains a `CHANGELOG.md` file per track branch. The changelog documents changes relative to the previous track.

### Branch structure

| Branch | Changelog contains |
|--------|-------------------|
| `main` | Changes since the newest `track/X.Y` branch |
| `track/4.0` | Changes since `track/3.0` |
| `track/0.31` | Changes since `track/0.28` |
| `track/X.Y` | Changes since the previous `track/` branch |

### Workflow

1. **During development on `main`**: Contributors add entries to `CHANGELOG.md` under an `## [Unreleased]` section as part of their PRs.

2. **When cutting a new track branch** (e.g., `track/5.0` from `main`):
   - The new `track/5.0` branch keeps the current `CHANGELOG.md` as-is (documenting changes since `track/4.0`).
   - On `main`, reset `CHANGELOG.md` to a fresh template with only the `## [Unreleased]` header, since `main` now tracks changes relative to `track/5.0`.

3. **Generating changelog content**: Use `just changelog <ref>` to generate a draft changelog from conventional commits between the current branch and a reference branch/commit. Review and edit the output before adding to `CHANGELOG.md`.

### Changelog format

```markdown
# Changelog

## [Unreleased]

### Breaking Changes
- description of breaking change

### Features
- description of new feature

### Fixes
- description of bug fix

### Others
- other notable changes (refactoring, docs, tests, etc.)
```

## Benefits

- **Clear upgrade path**: Users can see what changed between tracks they're upgrading from/to.
- **Track isolation**: Each track branch is self-contained with its own changelog history.
- **Simple reset model**: When a new track branches off, `main` starts fresh, avoiding changelog merge conflicts.
- **Automation-friendly**: The `just changelog` recipe provides a starting point from commit history.

## Disadvantages

- **Manual curation**: Generated changelogs need human review to be user-friendly.
- **Reset discipline**: Maintainers must remember to reset `main`'s changelog when cutting a new track.
- **Non-linear history**: If hotfixes are cherry-picked between tracks, they may appear in multiple changelogs.

## Alternatives considered

- **Single changelog across all branches**: Rejected because merge conflicts become unmanageable and it's unclear what version introduced which change.
- **Tag-based changelogs only**: Rejected because tracks don't always align with tags, and we need visibility into unreleased changes.
- **Automated changelog generation at release time**: Rejected because commit messages alone lack user-facing context; human curation produces better results.

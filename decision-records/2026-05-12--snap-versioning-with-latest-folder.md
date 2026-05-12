**Date:** 2026-05-12

## Context and Problem Statement

Our snap repositories currently use a single-version approach: one `snap/snapcraft.yaml` at the repository root that tracks the latest upstream release and publishes to `latest/edge`. This works well for following upstream, but doesn't support maintaining multiple tracks (e.g., `3.2/stable` alongside `latest/stable`).

When users need to pin to a specific major.minor version for stability, we have no mechanism to continue publishing patch releases to that track while also advancing `latest/` to newer major.minor versions.

## Decision

We adopt a folder-based structure with a mandatory `latest/` folder and optional, manually-created `X.Y/` track folders:

### Structure

```
snap-name/
├── justfile            # Imports snaps.just
├── snaps.just          # Shared recipes from canonical/observability
├── spread.yaml         # Shared spread config
├── latest/             # Always present, tracks latest upstream
│   └── snap/snapcraft.yaml
└── X.Y/                # Optional, manually created for specific tracks
    └── snap/snapcraft.yaml
```

### Behavior

| Component | Old Behavior | New Behavior |
|-----------|--------------|--------------|
| **Folder structure** | Single `snap/` at root | `latest/` folder + optional `X.Y/` folders |
| **Track support** | Only `latest/` track | Multiple tracks via folders |
| **Update automation** | Updates single snapcraft.yaml | Updates `latest/`; updates `X.Y/` only if it exists |
| **Folder creation** | N/A | Manual and intentional |

### Update Logic

The `just update <source-repo>` recipe:

1. Fetches the latest upstream release tag
2. Parses full semver (`X.Y.Z`) from the tag
3. Compares with current version in `latest/snap/snapcraft.yaml` using `sort -V`
4. If upstream is newer:
   - Updates `latest/` folder
   - Updates `X.Y/` folder **if it exists** (no auto-creation)

### Release Logic

Each folder releases to its corresponding track only:
- `latest/` → `latest/edge`
- `X.Y/` → `X.Y/edge`

Track folders are opt-in maintenance commitments — they only receive updates if they exist.

## Benefits

- **Multi-track support**: Can maintain `3.2/stable` while advancing `latest/` to `3.3`
- **Intentional track creation**: New tracks require explicit action (creating a folder, requesting track in Snap Store)
- **Backward compatible**: Repos with only `latest/` behave like before
- **Full semver tracking**: Storing `X.Y.Z` in `snapcraft.yaml` enables accurate version comparison for patch releases

## Disadvantages

- **Migration required**: Existing snap repos need restructuring (`snap/` → `latest/snap/`)
- **More folders**: Slightly more complex directory structure

## Migration

For existing snap repositories:

```bash
# 1. Restructure to folder-based layout
mkdir -p latest
mv snap latest/

# 2. Get the shared recipes
just refresh

# 3. Optionally create track folders for versions you want to maintain
cp -r latest/ 3.2/
```

## Files Changed

- `blueprints/snaps/snaps.just`: New `update` and `release` recipes supporting folder structure
- `blueprints/snaps/README.md`: Updated documentation
- `.github/workflows/snap-update.yaml`: Detects file modifications; updated PR messaging

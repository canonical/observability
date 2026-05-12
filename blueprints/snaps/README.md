**Centralized:** `snaps.just` | `spread.yaml`
**Dependencies:** `gh` | `snapcraft` | `just` | `yq`

This directory provides the shared baseline files used across Observability snap repositories.

When bootstrapping a new snap, initialize it with the files from this folder so repositories stay consistent.

## Structure

```
snap-name
├── justfile        # Main justfile: imports 'snaps.just' and allows for overrides
├── snaps.just      # (*) Shared snap recipes
├── spread.yaml     # (*) Shared spread configuration
├── latest/         # Always present, tracks latest upstream version
│   └── snap/
│       └── snapcraft.yaml
└── X.Y/            # Optional, manually created for specific tracks
    └── snap/
        └── snapcraft.yaml
```

## Versioning & Channels

The `latest/` folder always exists and tracks the most recent upstream release. It releases to `latest/edge`.

Track-specific `X.Y/` folders are **optional and manually created** when you want to maintain a specific track. They release to `X.Y/edge`.

| Folder     | Channel       | Created      |
|------------|---------------|--------------|
| `latest/`  | `latest/edge` | Always       |
| `X.Y/`     | `X.Y/edge`    | Manually     |

### Automatic Updates

The `just update <source-repo>` recipe:

1. Fetches the latest upstream release
2. Compares with the current version in `latest/snap/snapcraft.yaml`
3. If upstream is newer:
   - Updates `latest/` folder to the new version
   - Updates `X.Y/` folder **if it exists** (no auto-creation)

This means track creation is always intentional — you must manually create `X.Y/` folders when you want to support a specific track.

### Creating a New Track

To add support for a new `X.Y` track:

```bash
cp -r latest/ X.Y/
# Request track creation in the Snap Store if needed
```

## Recipes

| Recipe | Description |
|--------|-------------|
| `just update <repo>` | Update to latest upstream version |
| `just pack [version]` | Build snap locally |
| `just test [version]` | Run spread tests |
| `just remote-build [version] [arch]` | Build via Launchpad |
| `just release [version]` | Upload and release to edge |
| `just promote [version] [risk]` | Promote to next risk level |
| `just refresh` | Fetch latest centralized files |

To refresh the centralized files, run `just refresh`.

For project-specific customizations, see [../README.md#customization](../README.md#customization).

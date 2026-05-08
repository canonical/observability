**Centralized:** `snaps.just` | `spread.yaml`
**Dependencies:** `gh` | `snapcraft` | `just`

This directory provides the shared baseline files used across Observability snap repositories.

When bootstrapping a new snap, initialize it with the files from this folder so repositories stay consistent.

## Structure

```
snap-name
├── justfile        # Main justfile: imports 'snaps.just' and allows for overrides
├── snaps.just      # (*) Shared snap recipes
├── spread.yaml     # (*) Shared spread configuration
└── X.Y/            # One folder per major.minor version
    └── snap/
        └── snapcraft.yaml
```

## Versioning & Channels

Each snap version lives in its own `X.Y` folder. The release channel is derived from the folder name:

| Version folder | Channel(s) |
|----------------|------------|
| Latest `X.Y`   | `X.Y/edge` + `latest/edge` |
| Older `X.Y`    | `X.Y/edge` |

To refresh the centralized files, run `just refresh`.

For project-specific customizations, see [../README.md#customization](../README.md#customization).

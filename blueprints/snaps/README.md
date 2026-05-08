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
└── snapcraft.yaml  # Snap definition at the repository root
```

## Branching & Channels

The release channel is derived from the current git branch:

| Branch | Channel |
|--------|---------|
| `main` | `latest/edge` |
| `track/X.Y` | `X.Y/edge` |
| `<other>` | `latest/edge/<other>` |

To refresh the centralized files, run `just refresh`.

For project-specific customizations, see [../README.md#customization](../README.md#customization).

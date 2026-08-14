**Centralized:** `rocks.just` | `spread.yaml`
**Dependencies:** `gh` | `docker` | `uv` | `just`

This directory provides the shared baseline files used across Observability rock repositories.

When bootstrapping a new rock, initialize it with the files from this folder so repositories stay consistent.

## Structure

```
rock-name
├── justfile     # Main justfile: imports 'rock.just' and allows for overrides
├── README.md    # This README
├── rocks.just    # (*) Shared rock recipes
└── spread.yaml  # (*) Shared spread configuration
```

To refresh the centralized files, run `just refresh`.

For project-specific customizations, see [../README.md#customization](../README.md#customization).

## Folder structure

Each rock repository keeps one folder per maintained `major.minor` release
line (e.g. `0.31/`, `0.32/`, `0.33/`), each with its own `rockcraft.yaml`.
There is no `latest/` folder: the concrete version and upstream tag are
recorded inside each folder's `rockcraft.yaml` (`version` +
`parts.<name>.source-tag`), not in the folder name.

- **New release lines are added manually**, roughly every six months, via
  `just add-version <version>`. This resolves the newest real upstream tag on
  the given `major.minor` line and fails if none exists.
- **The scheduled `update` automation only patches existing folders** to the
  newest upstream patch of their own line. It never creates a new folder or
  jumps to a new minor, so onboarding a new release line stays a deliberate,
  reviewed action.

Set `source_repo` (upstream `org/repo`) in the repository's local `justfile`
so `update`, `add-version`, and `govulncheck` don't need it passed explicitly.


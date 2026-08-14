**Centralized:** `rocks.just` | `spread.yaml`
**Dependencies:** `gh` | `docker` | `uv` | `just`

This directory provides the shared baseline files used across Observability rock repositories.

When bootstrapping a new rock, initialize it with the files from this folder so repositories stay consistent.

## Structure

```
rock-name
├── justfile     # Main justfile: imports 'rocks.just' and allows for overrides
├── rocks.just   # (*) Shared rock recipes
├── spread.yaml  # (*) Shared spread configuration
└── X.Y/         # One per maintained release line, manually created
    └── rockcraft.yaml
```

## Versioning & Release Lines

There is no `latest/` folder for rocks. Every maintained upstream `major.minor`
release line has its own `X.Y/` folder, with the concrete version and upstream
tag recorded inside that folder's `rockcraft.yaml` (`version` and
`parts.<name>.source-tag`), not in the folder name.

`X.Y/` folders are **manually created** when you want to maintain a specific
release line.

| Folder | Created  |
|--------|----------|
| `X.Y/` | Manually |

### Automatic Updates

The `just update` recipe:

1. Fetches upstream releases for the repo set in the `source_repo` variable
2. For each existing `X.Y/` folder, finds the newest upstream patch on that line
3. If upstream is newer, updates that folder's `rockcraft.yaml` (`version` +
   `source-tag`)

This never creates or removes an `X.Y/` folder, so onboarding a new release
line is always intentional.

### Creating a New Release Line

To add support for a new `X.Y` release line:

```bash
just add-version X.Y
```

This resolves the newest real upstream tag on the given `major.minor` line and
fails if none exists.

## Recipes

| Recipe | Description |
|--------|-------------|
| `just update` | Patch existing `X.Y/` folders to their newest upstream release |
| `just add-version <version>` | Create a new `X.Y/` release line |
| `just pack [version]` | Build a rock locally |
| `just test [version]` | Run spread tests |
| `just scan [version]` | Generate SBOM and run a vulnerability scan |
| `just release-ghcr [version]` | Push a `:dev` tag to GHCR |
| `just release-oci-factory [version]` | Open a PR to OCI Factory |
| `just refresh` | Fetch latest centralized files |

Set `source_repo` (upstream `org/repo`) in the repository's local `justfile`
so `update`, `add-version`, and `govulncheck` don't need it passed explicitly.

To refresh the centralized files, run `just refresh`.

For project-specific customizations, see [../README.md#customization](../README.md#customization).

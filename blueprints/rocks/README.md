**Centralized:** `rock.just` | `spread.yaml`

This directory provides the shared baseline files used across Observability rock repositories.

When bootstrapping a new rock, initialize it with the files from this folder so repositories stay consistent.

## Structure

```
rock-name
├── justfile     # Main justfile: imports 'rock.just' and allows for overrides
├── README.md    # This README
├── rock.just    # (*) Shared rock recipes
└── spread.yaml  # (*) Shared spread configuration
```

To refresh the centralized files, run `just refresh`.

For project-specific customizations, see [../README.md#customization](../README.md#customization).

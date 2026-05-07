**Centralized:** `charms.just`
**Dependencies:** `gh` | `just`

This directory provides the shared baseline files used across Observability charm repositories.

When bootstrapping a new charm, initialize it with the files from this folder so repositories stay consistent.

## Structure

```
charm-name
├── justfile      # Main justfile: imports 'charms.just' and allows for overrides
├── README.md     # This README
└── charms.just   # (*) Shared charm recipes
```

To refresh the centralized files, run `just refresh`.

For project-specific customizations, see [../README.md#customization](../README.md#customization).

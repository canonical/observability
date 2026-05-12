**Centralized:** `charms.just`
**Dependencies:** `gh` | `just`

This directory provides the shared baseline files used across Observability charm repositories.

When bootstrapping a new charm, initialize it with the files from this folder so repositories stay consistent.

## Structure

```
charm-name
├── justfile      # Main justfile: imports 'charms.just' and allows for overrides
└── charms.just   # (*) Shared charm recipes
```

For project-specific customizations, see [../README.md#customization](../README.md#customization).

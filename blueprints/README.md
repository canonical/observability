# Blueprints

Blueprints are shared templates for Observability components. They provide centralized files and conventions so new repositories start with consistent tooling and configuration.

Use a blueprint by copying the files into a new repository, then keep centralized files in sync  via `just refresh`.

## Available blueprints

- `rocks`: Shared files and workflows for Observability rock repositories. See [rocks/README.md](rocks/README.md).


## Customization

Blueprints define a centralized set of recipes in `<blueprint>.just`. These recipes can be extended or overridden in the central `justfile`, allowing for project-specific behaviors.

To override or extend a shared recipe, define one with the same name in `justfile`:

```just
# ./justfile
set allow-duplicate-recipes
set allow-duplicate-variables
import? '<blueprint>.just'

[private]
@default:
	just --list
	echo ""
	echo "For help with a specific recipe, run: just --usage <recipe>"

# Recipe from <blueprint.just> that overrides the imported behavior
update version:
    echo "New things happen here"

# Recipe from <blueprint.just> to extend
update version:
    # Manually invoke the recipe from the centralized justfile
    just --justfile <blueprint>.just update {{version}}
    # Add your custom logic
    echo "Additional things happen here"
```


set quiet  # Recipes are silent by default
set export  # Just variables are exported to the environment

[private]
default:
  just --list

# Lint everything
[group("Lint")]
lint: lint-workflows

# Format everything 
# [group("Format")]
# fmt: format-terraform

# Lint the Github workflows
[group("Lint")]
lint-workflows:
  uvx --from=actionlint-py actionlint

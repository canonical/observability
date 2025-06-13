set quiet  # Recipes are silent by default
set export  # Just variables are exported to the environment

terraform := `which terraform || which tofu || echo ""` # require 'terraform' or 'opentofu'

[private]
default:
  just --list

# Lint everything
[group("Lint")]
lint: lint-terraform lint-workflows

# Format everything 
[group("Format")]
fmt: format-terraform

# Lint the Terraform modules
[group("Lint")]
lint-terraform:
  if [ -z "${terraform}" ]; then echo "ERROR: please install terraform or opentofu"; exit 1; fi
  $terraform fmt -check -recursive -diff

# Lint the Github workflows
[group("Lint")]
lint-workflows:
  uvx --from=actionlint-py actionlint

# Format the Terraform modules
[group("Format")]
format-terraform:
  if [ -z "${terraform}" ]; then echo "ERROR: please install terraform or opentofu"; exit 1; fi
  $terraform fmt -recursive -diff

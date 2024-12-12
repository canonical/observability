set quiet  # Recipes are silent by default
set export  # Just variables are exported to the environment

terraform := `which terraform || which tofu || echo ""` # require 'terraform' or 'opentofu'

[private]
default:
  just --list

# Lint the Terraform modules
lint-terraform:
  if [ -z "${terraform}" ]; then echo "ERROR: please install terraform or opentofu"; exit 1; fi
  $terraform fmt -check -recursive -diff

# Lint the Github workflows
lint-workflows:
  uvx --from=actionlint-py actionlint

# Lint everything
lint: lint-terraform lint-workflows


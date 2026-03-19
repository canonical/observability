set shell := ["bash", "-uc"]

gh := `which gh`
terraform := `which terraform || which tofu`


[private]
@default:
  just -f {{justfile_directory()}}/deploy.just --list

# Deploy `cos-lite` from its Terraform module
cos-lite:
  mkdir -p deployments/active
  cp deployments/cos-lite.tf deployments/active/main.tf
  cd deployments/active; {{terraform}} init && {{terraform}} apply


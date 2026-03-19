terraform {
  required_version = ">= 1.5"
  required_providers {
    juju = {
      source  = "juju/juju"
      version = "~> 1.0"
    }
  }
}

resource "juju_model" "cos" {
  name = "cos"
}

module "cos-lite" {
  source     = "git::https://github.com/canonical/observability-stack//terraform/cos-lite?ref=track/2"
  model_uuid = juju_model.cos.uuid
  channel    = "2/stable"
}

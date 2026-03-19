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

module "cos" {
  source     = "git::https://github.com/canonical/observability-stack//terraform/cos?ref=track/2"
  model_uuid = juju_model.cos.uuid
  channel    = "2/stable"

  s3_endpoint   = "http://S3_HOST_IP:8080"
  s3_secret_key = "secret-key"
  s3_access_key = "access-key"
}

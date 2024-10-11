module "grafana" {
  source     = "git::https://github.com/canonical/grafana-k8s-operator//terraform?ref=feature/terraform"
  app_name   = "grafana"
  model_name = var.model_name
  channel    = var.channel
}

module "mimir" {
  source                = "../mimir-ha"
  model_name            = var.model_name
  channel               = var.channel
  create_s3_integrator  = false
}

module "ssc" {
  count      = var.use_tls ? 1 : 0
  source     = "git::https://github.com/canonical/self-signed-certificates-operator//terraform"
  model_name = var.model_name
  channel    = var.channel
}

# TODO: Replace s3_integrator resource to use its remote terraform module once available
resource "juju_application" "s3_integrator" {
  name = "s3-integrator"

  model = var.model_name
  trust = true

  charm {
    name    = "s3-integrator"
    channel = var.channel
  }
  units = 1

}

# -------------- # Integrations --------------

resource "juju_integration" "coordinator_to_s3_integrator" {
  model = var.model_name

  application {
    name     = juju_application.s3_integrator.name
    endpoint = "s3-credentials"
  }

  application {
    name     = module.mimir.app_names.mimir_coordinator
    endpoint = "s3"
  }
}

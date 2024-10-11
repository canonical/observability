# TODO: Replace s3_integrator resource to use its remote terraform module once available
resource "juju_application" "s3_integrator" {
  count = var.create_s3_integrator ? 1 : 0
  name = "s3-integrator"
  model = var.model_name
  trust = true

  charm {
    name    = "s3-integrator"
    channel = var.channel
  }
  units = 1

}

module "mimir_coordinator" {
  source     = "git::https://github.com/canonical/mimir-coordinator-k8s-operator//terraform?ref=feature/terraform"
  app_name   = "mimir-coordinator"
  model_name = var.model_name
  channel    = var.channel
}

module "mimir_overrides_exporter" {
  source     = "git::https://github.com/canonical/mimir-worker-k8s-operator//terraform?ref=feature/terraform"
  app_name   = var.overrides_exporter_name
  model_name = var.model_name
  channel    = var.channel
  config = {
    role-all                = false
    role-overrides-exporter = true
  }
  units = var.overrides_exporter_units
}

module "mimir_query_scheduler" {
  source     = "git::https://github.com/canonical/mimir-worker-k8s-operator//terraform?ref=feature/terraform"
  app_name   = var.query_scheduler_name
  model_name = var.model_name
  channel    = var.channel
  config = {
    role-all             = false
    role-query-scheduler = true
  }
  units = var.query_scheduler_units
}

module "mimir_flusher" {
  source     = "git::https://github.com/canonical/mimir-worker-k8s-operator//terraform?ref=feature/terraform"
  app_name   = var.flusher_name
  model_name = var.model_name
  channel    = var.channel
  config = {
    role-all     = false
    role-flusher = true
  }
  units = var.flusher_units
}

module "mimir_query_frontend" {
  source     = "git::https://github.com/canonical/mimir-worker-k8s-operator//terraform?ref=feature/terraform"
  app_name   = var.query_frontend_name
  model_name = var.model_name
  channel    = var.channel
  config = {
    role-all            = false
    role-query-frontend = true
  }
  units = var.query_frontend_units
}

module "mimir_querier" {
  source     = "git::https://github.com/canonical/mimir-worker-k8s-operator//terraform?ref=feature/terraform"
  app_name   = var.querier_name
  model_name = var.model_name
  channel    = var.channel
  config = {
    role-all     = false
    role-querier = true
  }
  units = var.querier_units
}

module "mimir_store_gateway" {
  source     = "git::https://github.com/canonical/mimir-worker-k8s-operator//terraform?ref=feature/terraform"
  app_name   = var.store_gateway_name
  model_name = var.model_name
  channel    = var.channel
  config = {
    role-all           = false
    role-store-gateway = true
  }
  units = var.store_gateway_units
}

module "mimir_ingester" {
  source     = "git::https://github.com/canonical/mimir-worker-k8s-operator//terraform?ref=feature/terraform"
  app_name   = var.ingester_name
  model_name = var.model_name
  channel    = var.channel
  config = {
    role-all      = false
    role-ingester = true
  }
  units = var.ingester_units
}

module "mimir_distributor" {
  source     = "git::https://github.com/canonical/mimir-worker-k8s-operator//terraform?ref=feature/terraform"
  app_name   = var.distributor_name
  model_name = var.model_name
  channel    = var.channel
  config = {
    role-all         = false
    role-distributor = true
  }
  units = var.distributor_units
}

module "mimir_ruler" {
  source     = "git::https://github.com/canonical/mimir-worker-k8s-operator//terraform?ref=feature/terraform"
  app_name   = var.ruler_name
  model_name = var.model_name
  channel    = var.channel
  config = {
    role-all   = false
    role-ruler = true
  }
  units = var.ruler_units
}

module "mimir_alertmanager" {
  source     = "git::https://github.com/canonical/mimir-worker-k8s-operator//terraform?ref=feature/terraform"
  app_name   = var.alertmanager_name
  model_name = var.model_name
  channel    = var.channel
  config = {
    role-all          = false
    role-alertmanager = true
  }
  units = var.alertmanager_units
}

module "mimir_compactor" {
  source     = "git::https://github.com/canonical/mimir-worker-k8s-operator//terraform?ref=feature/terraform"
  app_name   = var.compactor_name
  model_name = var.model_name
  channel    = var.channel
  config = {
    role-all       = false
    role-compactor = true
  }
  units = var.compactor_units
}

# -------------- # Integrations --------------

resource "juju_integration" "coordinator_to_s3_integrator" {
  count = var.create_s3_integrator ? 1 : 0
  model = var.model_name
  application {
    name     = juju_application.s3_integrator[0].name
    endpoint = "s3-credentials"
  }

  application {
    name     = module.mimir_coordinator.app_name
    endpoint = "s3"
  }
}

resource "juju_integration" "coordinator_to_overrides_exporter" {
  model = var.model_name

  application {
    name     = module.mimir_coordinator.app_name
    endpoint = "mimir-cluster"
  }

  application {
    name     = module.mimir_overrides_exporter.app_name
    endpoint = "mimir-cluster"
  }
}

resource "juju_integration" "coordinator_to_query_scheduler" {
  model = var.model_name

  application {
    name     = module.mimir_coordinator.app_name
    endpoint = "mimir-cluster"
  }

  application {
    name     = module.mimir_query_scheduler.app_name
    endpoint = "mimir-cluster"
  }
}

resource "juju_integration" "coordinator_to_flusher" {
  model = var.model_name

  application {
    name     = module.mimir_coordinator.app_name
    endpoint = "mimir-cluster"
  }

  application {
    name     = module.mimir_flusher.app_name
    endpoint = "mimir-cluster"
  }
}

resource "juju_integration" "coordinator_to_query_frontend" {
  model = var.model_name

  application {
    name     = module.mimir_coordinator.app_name
    endpoint = "mimir-cluster"
  }

  application {
    name     = module.mimir_query_frontend.app_name
    endpoint = "mimir-cluster"
  }
}

resource "juju_integration" "coordinator_to_querier" {
  model = var.model_name

  application {
    name     = module.mimir_coordinator.app_name
    endpoint = "mimir-cluster"
  }

  application {
    name     = module.mimir_querier.app_name
    endpoint = "mimir-cluster"
  }
}

resource "juju_integration" "coordinator_to_store_gateway" {
  model = var.model_name

  application {
    name     = module.mimir_coordinator.app_name
    endpoint = "mimir-cluster"
  }

  application {
    name     = module.mimir_store_gateway.app_name
    endpoint = "mimir-cluster"
  }
}

resource "juju_integration" "coordinator_to_ingester" {
  model = var.model_name

  application {
    name     = module.mimir_coordinator.app_name
    endpoint = "mimir-cluster"
  }

  application {
    name     = module.mimir_ingester.app_name
    endpoint = "mimir-cluster"
  }
}

resource "juju_integration" "coordinator_to_distributor" {
  model = var.model_name

  application {
    name     = module.mimir_coordinator.app_name
    endpoint = "mimir-cluster"
  }

  application {
    name     = module.mimir_distributor.app_name
    endpoint = "mimir-cluster"
  }
}

resource "juju_integration" "coordinator_to_ruler" {
  model = var.model_name

  application {
    name     = module.mimir_coordinator.app_name
    endpoint = "mimir-cluster"
  }

  application {
    name     = module.mimir_ruler.app_name
    endpoint = "mimir-cluster"
  }
}

resource "juju_integration" "coordinator_to_alertmanager" {
  model = var.model_name

  application {
    name     = module.mimir_coordinator.app_name
    endpoint = "mimir-cluster"
  }

  application {
    name     = module.mimir_alertmanager.app_name
    endpoint = "mimir-cluster"
  }
}

resource "juju_integration" "coordinator_to_compactor" {
  model = var.model_name

  application {
    name     = module.mimir_coordinator.app_name
    endpoint = "mimir-cluster"
  }

  application {
    name     = module.mimir_compactor.app_name
    endpoint = "mimir-cluster"
  }
}

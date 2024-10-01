module "tempo_coordinator" {
  source     = "git::https://github.com/canonical/tempo-coordinator-k8s-operator//terraform?ref=OPENG-2685"
  model_name = var.model_name
  channel    = var.channel
}

module "tempo_querier" {
  source     = "git::https://github.com/canonical/tempo-worker-k8s-operator//terraform?ref=OPENG-2685"
  app_name   = "tempo-querier"
  model_name = var.model_name
  channel    = var.channel
  config = {
    role-all     = false
    role-querier = true
  }
  units = var.querier_units
}
module "tempo_query_frontend" {
  source     = "git::https://github.com/canonical/tempo-worker-k8s-operator//terraform?ref=OPENG-2685"
  app_name   = "tempo-query-frontend"
  model_name = var.model_name
  channel    = var.channel
  config = {
    role-all            = false
    role-query-frontend = true
  }
  units = var.query_frontend_units
}
module "tempo_ingester" {
  source     = "git::https://github.com/canonical/tempo-worker-k8s-operator//terraform?ref=OPENG-2685"
  app_name   = "tempo-ingester"
  model_name = var.model_name
  channel    = var.channel
  config = {
    role-all      = false
    role-ingester = true
  }
  units = var.ingester_units
}
module "tempo_distributor" {
  source     = "git::https://github.com/canonical/tempo-worker-k8s-operator//terraform?ref=OPENG-2685"
  app_name   = "tempo-distributor"
  model_name = var.model_name
  channel    = var.channel
  config = {
    role-all         = false
    role-distributor = true
  }
  units = var.distributor_units
}
module "tempo_compactor" {
  source     = "git::https://github.com/canonical/tempo-worker-k8s-operator//terraform?ref=OPENG-2685"
  app_name   = "tempo-compactor"
  model_name = var.model_name
  channel    = var.channel
  config = {
    role-all       = false
    role-compactor = true
  }
  units = var.compactor_units
}
module "tempo_metrics_generator" {
  source     = "git::https://github.com/canonical/tempo-worker-k8s-operator//terraform?ref=OPENG-2685"
  app_name   = "tempo-metrics-generator"
  model_name = var.model_name
  channel    = var.channel
  config = {
    role-all               = false
    role-metrics-generator = true
  }
  units = var.metrics_generator_units
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

#Integrations

resource "juju_integration" "coordinator_to_s3_integrator" {
  model = var.model_name

  application {
    name     = juju_application.s3_integrator.name
    endpoint = "s3-credentials"
  }

  application {
    name     = module.tempo_coordinator.app_name
    endpoint = "s3"
  }
}

resource "juju_integration" "coordinator_to_ssc" {
  count = var.use_tls ? 1 : 0
  model = var.model_name

  application {
    name     = module.tempo_coordinator.app_name
    endpoint = "certificates"
  }

  application {
    name     = module.ssc[0].app_name
    endpoint = "certificates"
  }
}

resource "juju_integration" "coordinator_to_querier" {
  model = var.model_name

  application {
    name     = module.tempo_coordinator.app_name
    endpoint = "tempo-cluster"
  }

  application {
    name     = module.tempo_querier.app_name
    endpoint = "tempo-cluster"
  }
}

resource "juju_integration" "coordinator_to_query_frontend" {
  model = var.model_name

  application {
    name     = module.tempo_coordinator.app_name
    endpoint = "tempo-cluster"
  }

  application {
    name     = module.tempo_query_frontend.app_name
    endpoint = "tempo-cluster"
  }
}

resource "juju_integration" "coordinator_to_ingester" {
  model = var.model_name

  application {
    name     = module.tempo_coordinator.app_name
    endpoint = "tempo-cluster"
  }

  application {
    name     = module.tempo_ingester.app_name
    endpoint = "tempo-cluster"
  }
}

resource "juju_integration" "coordinator_to_distributor" {
  model = var.model_name

  application {
    name     = module.tempo_coordinator.app_name
    endpoint = "tempo-cluster"
  }

  application {
    name     = module.tempo_distributor.app_name
    endpoint = "tempo-cluster"
  }
}

resource "juju_integration" "coordinator_to_compactor" {
  model = var.model_name

  application {
    name     = module.tempo_coordinator.app_name
    endpoint = "tempo-cluster"
  }

  application {
    name     = module.tempo_compactor.app_name
    endpoint = "tempo-cluster"
  }
}

resource "juju_integration" "coordinator_to_metrics_generator" {
  model = var.model_name

  application {
    name     = module.tempo_coordinator.app_name
    endpoint = "tempo-cluster"
  }

  application {
    name     = module.tempo_metrics_generator.app_name
    endpoint = "tempo-cluster"
  }
}
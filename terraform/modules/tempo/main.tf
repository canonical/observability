resource "juju_secret" "tempo_s3_credentials_secret" {
  model = var.model
  name  = "tempo_s3_credentials"
  value = {
    access-key = var.s3_access_key
    secret-key = var.s3_secret_key
  }
  info = "Credentials for the S3 endpoint"
}

resource "juju_access_secret" "tempo_s3_secret_access" {
  model = var.model
  applications = [
    juju_application.s3_integrator.name
  ]
  secret_id = juju_secret.tempo_s3_credentials_secret.secret_id
}

# TODO: Replace s3_integrator resource to use its remote terraform module once available
resource "juju_application" "s3_integrator" {
  name  = var.s3_integrator_name
  model = var.model
  trust = true

  charm {
    name     = "s3-integrator"
    channel  = var.s3_integrator_channel
    revision = var.s3_integrator_revision
  }
  config = {
    endpoint    = var.s3_endpoint
    bucket      = var.s3_bucket
    credentials = "secret:${juju_secret.tempo_s3_credentials_secret.secret_id}"
  }
  units = 1
}

module "tempo_coordinator" {
  source      = "git::https://github.com/canonical/tempo-coordinator-k8s-operator//terraform"
  model       = var.model
  channel     = var.channel
  revision    = var.coordinator_revision
  units       = var.coordinator_units
  constraints = var.anti_affinity ? "arch=amd64 tags=anti-pod.app.kubernetes.io/name=tempo,anti-pod.topology-key=kubernetes.io/hostname" : null
}

module "tempo_querier" {
  source      = "git::https://github.com/canonical/tempo-worker-k8s-operator//terraform"
  app_name    = var.querier_name
  model       = var.model
  channel     = var.channel
  constraints = var.anti_affinity ? "arch=amd64 tags=anti-pod.app.kubernetes.io/name=${var.querier_name},anti-pod.topology-key=kubernetes.io/hostname" : null
  config = {
    role-all     = false
    role-querier = true
  }
  revision = var.worker_revision
  units    = var.querier_units
  depends_on = [
    module.tempo_coordinator
  ]
}

module "tempo_query_frontend" {
  source      = "git::https://github.com/canonical/tempo-worker-k8s-operator//terraform"
  app_name    = var.query_frontend_name
  model       = var.model
  channel     = var.channel
  constraints = var.anti_affinity ? "arch=amd64 tags=anti-pod.app.kubernetes.io/name=${var.query_frontend_name},anti-pod.topology-key=kubernetes.io/hostname" : null
  config = {
    role-all            = false
    role-query-frontend = true
  }
  revision = var.worker_revision
  units    = var.query_frontend_units
  depends_on = [
    module.tempo_coordinator
  ]
}

module "tempo_ingester" {
  source      = "git::https://github.com/canonical/tempo-worker-k8s-operator//terraform"
  app_name    = var.ingester_name
  model       = var.model
  channel     = var.channel
  constraints = var.anti_affinity ? "arch=amd64 tags=anti-pod.app.kubernetes.io/name=${var.ingester_name},anti-pod.topology-key=kubernetes.io/hostname" : null
  config = {
    role-all      = false
    role-ingester = true
  }
  revision = var.worker_revision
  units    = var.ingester_units
  depends_on = [
    module.tempo_coordinator
  ]
}

module "tempo_distributor" {
  source      = "git::https://github.com/canonical/tempo-worker-k8s-operator//terraform"
  app_name    = var.distributor_name
  model       = var.model
  channel     = var.channel
  constraints = var.anti_affinity ? "arch=amd64 tags=anti-pod.app.kubernetes.io/name=${var.distributor_name},anti-pod.topology-key=kubernetes.io/hostname" : null
  config = {
    role-all         = false
    role-distributor = true
  }
  revision = var.worker_revision
  units    = var.distributor_units
  depends_on = [
    module.tempo_coordinator
  ]
}

module "tempo_compactor" {
  source      = "git::https://github.com/canonical/tempo-worker-k8s-operator//terraform"
  app_name    = var.compactor_name
  model       = var.model
  channel     = var.channel
  constraints = var.anti_affinity ? "arch=amd64 tags=anti-pod.app.kubernetes.io/name=${var.compactor_name},anti-pod.topology-key=kubernetes.io/hostname" : null
  config = {
    role-all       = false
    role-compactor = true
  }
  revision = var.worker_revision
  units    = var.compactor_units
  depends_on = [
    module.tempo_coordinator
  ]
}

module "tempo_metrics_generator" {
  source      = "git::https://github.com/canonical/tempo-worker-k8s-operator//terraform"
  app_name    = var.metrics_generator_name
  model       = var.model
  channel     = var.channel
  constraints = var.anti_affinity ? "arch=amd64 tags=anti-pod.app.kubernetes.io/name=${var.metrics_generator_name},anti-pod.topology-key=kubernetes.io/hostname" : null
  config = {
    role-all               = false
    role-metrics-generator = true
  }
  revision = var.worker_revision
  units    = var.metrics_generator_units
  depends_on = [
    module.tempo_coordinator
  ]
}

#Integrations

resource "juju_integration" "coordinator_to_s3_integrator" {
  model = var.model

  application {
    name     = juju_application.s3_integrator.name
    endpoint = "s3-credentials"
  }

  application {
    name     = module.tempo_coordinator.app_name
    endpoint = "s3"
  }
}

resource "juju_integration" "coordinator_to_querier" {
  model = var.model

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
  model = var.model

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
  model = var.model

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
  model = var.model

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
  model = var.model

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
  model = var.model

  application {
    name     = module.tempo_coordinator.app_name
    endpoint = "tempo-cluster"
  }

  application {
    name     = module.tempo_metrics_generator.app_name
    endpoint = "tempo-cluster"
  }
}

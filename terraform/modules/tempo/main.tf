module "tempo_coordinator" {
  source      = "git::https://github.com/canonical/tempo-coordinator-k8s-operator//terraform"
  model_name  = var.model_name
  channel     = var.channel
  units       = var.coordinator_units
  constraints = var.anti_affinity ? "arch=amd64 tags=anti-pod.app.kubernetes.io/name=tempo,anti-pod.topology-key=kubernetes.io/hostname" : null
}

module "tempo_querier" {
  source      = "git::https://github.com/canonical/tempo-worker-k8s-operator//terraform"
  app_name    = "tempo-querier"
  model_name  = var.model_name
  channel     = var.channel
  constraints = var.anti_affinity ? "arch=amd64 tags=anti-pod.app.kubernetes.io/name=tempo-querier,anti-pod.topology-key=kubernetes.io/hostname" : null
  config = {
    role-all     = false
    role-querier = true
  }
  units = var.querier_units
  depends_on = [
    module.tempo_coordinator
  ]
}
module "tempo_query_frontend" {
  source      = "git::https://github.com/canonical/tempo-worker-k8s-operator//terraform"
  app_name    = "tempo-query-frontend"
  model_name  = var.model_name
  channel     = var.channel
  constraints = var.anti_affinity ? "arch=amd64 tags=anti-pod.app.kubernetes.io/name=tempo-query-frontend,anti-pod.topology-key=kubernetes.io/hostname" : null
  config = {
    role-all            = false
    role-query-frontend = true
  }
  units = var.query_frontend_units
  depends_on = [
    module.tempo_coordinator
  ]
}
module "tempo_ingester" {
  source      = "git::https://github.com/canonical/tempo-worker-k8s-operator//terraform"
  app_name    = "tempo-ingester"
  model_name  = var.model_name
  channel     = var.channel
  constraints = var.anti_affinity ? "arch=amd64 tags=anti-pod.app.kubernetes.io/name=tempo-ingester,anti-pod.topology-key=kubernetes.io/hostname" : null
  config = {
    role-all      = false
    role-ingester = true
  }
  units = var.ingester_units
  depends_on = [
    module.tempo_coordinator
  ]
}
module "tempo_distributor" {
  source      = "git::https://github.com/canonical/tempo-worker-k8s-operator//terraform"
  app_name    = "tempo-distributor"
  model_name  = var.model_name
  channel     = var.channel
  constraints = var.anti_affinity ? "arch=amd64 tags=anti-pod.app.kubernetes.io/name=tempo-distributor,anti-pod.topology-key=kubernetes.io/hostname" : null
  config = {
    role-all         = false
    role-distributor = true
  }
  units = var.distributor_units
  depends_on = [
    module.tempo_coordinator
  ]
}
module "tempo_compactor" {
  source      = "git::https://github.com/canonical/tempo-worker-k8s-operator//terraform"
  app_name    = "tempo-compactor"
  model_name  = var.model_name
  channel     = var.channel
  constraints = var.anti_affinity ? "arch=amd64 tags=anti-pod.app.kubernetes.io/name=tempo-compactor,anti-pod.topology-key=kubernetes.io/hostname" : null
  config = {
    role-all       = false
    role-compactor = true
  }
  units = var.compactor_units
  depends_on = [
    module.tempo_coordinator
  ]
}
module "tempo_metrics_generator" {
  source      = "git::https://github.com/canonical/tempo-worker-k8s-operator//terraform"
  app_name    = "tempo-metrics-generator"
  model_name  = var.model_name
  channel     = var.channel
  constraints = var.anti_affinity ? "arch=amd64 tags=anti-pod.app.kubernetes.io/name=tempo-metrics-generator,anti-pod.topology-key=kubernetes.io/hostname" : null
  config = {
    role-all               = false
    role-metrics-generator = true
  }
  units = var.metrics_generator_units
  depends_on = [
    module.tempo_coordinator
  ]
}

# TODO: Replace s3_integrator resource to use its remote terraform module once available
resource "juju_application" "s3_integrator" {
  name  = var.s3_integrator_name
  model = var.model_name
  trust = true

  charm {
    name    = "s3-integrator"
    channel = var.channel
  }
  config = {
    endpoint = var.s3_endpoint
    bucket   = var.s3_bucket
  }
  units = 1

}

resource "terraform_data" "s3management" {
  depends_on = [
    juju_application.s3_integrator
  ]
  input = {
    S3_USER       = var.s3_user
    S3_PASSWORD   = var.s3_password
    MODEL_NAME    = var.model_name
    S3_INTEGRATOR = var.s3_integrator_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      juju wait-for application -m "${self.input.MODEL_NAME}" "${self.input.S3_INTEGRATOR}" --query='forEach(units,  unit => unit.workload-status=="blocked" && unit.agent-status=="idle")' --timeout=30m
      juju run -m "${self.input.MODEL_NAME}" "${self.input.S3_INTEGRATOR}/leader" sync-s3-credentials access-key="${self.input.S3_USER}" secret-key="${self.input.S3_PASSWORD}"
    EOT
  }
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

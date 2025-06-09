# TODO: Replace s3_integrator resource to use its remote terraform module once available
resource "juju_application" "s3_integrator" {
  name  = var.s3_integrator_name
  model = var.model
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
    juju_application.s3_integrator,
  ]
  input = {
    S3_USER       = var.s3_access_key
    S3_PASSWORD   = var.s3_secret_key
    MODEL_NAME    = var.model
    S3_INTEGRATOR = var.s3_integrator_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      juju wait-for application -m "${self.input.MODEL_NAME}" "${self.input.S3_INTEGRATOR}" --query='forEach(units,  unit => unit.workload-status=="blocked" && unit.agent-status=="idle")' --timeout=30m
      juju run -m "${self.input.MODEL_NAME}" "${self.input.S3_INTEGRATOR}/leader" sync-s3-credentials access-key="${self.input.S3_USER}" secret-key="${self.input.S3_PASSWORD}"
    EOT
  }
}

module "loki_coordinator" {
  source     = "git::https://github.com/canonical/loki-coordinator-k8s-operator//terraform"
  app_name   = "loki"
  model = var.model
  channel    = var.channel
  units      = var.coordinator_units
}

module "loki_backend" {
  source     = "git::https://github.com/canonical/loki-worker-k8s-operator//terraform"
  app_name   = var.backend_name
  model = var.model
  channel    = var.channel
  config = {
    role-backend = true
  }
  units = var.backend_units
  depends_on = [
    module.loki_coordinator
  ]
}

module "loki_read" {
  source     = "git::https://github.com/canonical/loki-worker-k8s-operator//terraform"
  app_name   = var.read_name
  model = var.model
  channel    = var.channel
  config = {
    role-read = true
  }
  units = var.read_units
  depends_on = [
    module.loki_coordinator
  ]
}

module "loki_write" {
  source     = "git::https://github.com/canonical/loki-worker-k8s-operator//terraform"
  app_name   = var.write_name
  model = var.model
  channel    = var.channel
  config = {
    role-write = true
  }
  units = var.write_units
  depends_on = [
    module.loki_coordinator
  ]
}

# -------------- # Integrations --------------

resource "juju_integration" "coordinator_to_s3_integrator" {
  model = var.model
  application {
    name     = juju_application.s3_integrator.name
    endpoint = "s3-credentials"
  }

  application {
    name     = module.loki_coordinator.app_name
    endpoint = "s3"
  }
}

resource "juju_integration" "coordinator_to_backend" {
  model = var.model

  application {
    name     = module.loki_coordinator.app_name
    endpoint = "loki-cluster"
  }

  application {
    name     = module.loki_backend.app_name
    endpoint = "loki-cluster"
  }
}

resource "juju_integration" "coordinator_to_read" {
  model = var.model

  application {
    name     = module.loki_coordinator.app_name
    endpoint = "loki-cluster"
  }

  application {
    name     = module.loki_read.app_name
    endpoint = "loki-cluster"
  }
}

resource "juju_integration" "coordinator_to_write" {
  model = var.model

  application {
    name     = module.loki_coordinator.app_name
    endpoint = "loki-cluster"
  }

  application {
    name     = module.loki_write.app_name
    endpoint = "loki-cluster"
  }
}

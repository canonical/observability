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
    juju_application.s3_integrator,
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

module "mimir_coordinator" {
  source     = "git::https://github.com/canonical/mimir-coordinator-k8s-operator//terraform"
  app_name   = "mimir"
  model_name = var.model_name
  channel    = var.channel
}

module "mimir_read" {
  source     = "git::https://github.com/canonical/mimir-worker-k8s-operator//terraform"
  app_name   = var.read_name
  model_name = var.model_name
  channel    = var.channel
  config = {
    role-read = true
  }
  units = var.read_units
}

module "mimir_write" {
  source     = "git::https://github.com/canonical/mimir-worker-k8s-operator//terraform"
  app_name   = var.write_name
  model_name = var.model_name
  channel    = var.channel
  config = {
    role-write = true
  }
  units = var.write_units
}

module "mimir_backend" {
  source     = "git::https://github.com/canonical/mimir-worker-k8s-operator//terraform"
  app_name   = var.backend_name
  model_name = var.model_name
  channel    = var.channel
  config = {
    role-backend = true
  }
  units = var.backend_units
}

# -------------- # Integrations --------------

resource "juju_integration" "coordinator_to_s3_integrator" {
  model = var.model_name
  application {
    name     = juju_application.s3_integrator.name
    endpoint = "s3-credentials"
  }

  application {
    name     = module.mimir_coordinator.app_name
    endpoint = "s3"
  }
}

resource "juju_integration" "coordinator_to_read" {
  model = var.model_name

  application {
    name     = module.mimir_coordinator.app_name
    endpoint = "mimir-cluster"
  }

  application {
    name     = module.mimir_read.app_name
    endpoint = "mimir-cluster"
  }
}

resource "juju_integration" "coordinator_to_write" {
  model = var.model_name

  application {
    name     = module.mimir_coordinator.app_name
    endpoint = "mimir-cluster"
  }

  application {
    name     = module.mimir_write.app_name
    endpoint = "mimir-cluster"
  }
}

resource "juju_integration" "coordinator_to_backend" {
  model = var.model_name

  application {
    name     = module.mimir_coordinator.app_name
    endpoint = "mimir-cluster"
  }

  application {
    name     = module.mimir_backend.app_name
    endpoint = "mimir-cluster"
  }
}
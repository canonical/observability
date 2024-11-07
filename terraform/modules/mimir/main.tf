# TODO: Replace s3_integrator resource to use its remote terraform module once available
resource "juju_application" "s3_integrator" {
  name  = "mimir-s3-bucket"
  model = var.model_name
  trust = true

  charm {
    name    = "s3-integrator"
    channel = var.channel
  }
  units = 1

}

module "mimir_coordinator" {
  source     = "git::https://github.com/canonical/mimir-coordinator-k8s-operator//terraform"
  app_name   = "mimir"
  model_name = var.model_name
  channel    = var.channel
}

module "mimir_meta_read" {
  source     = "git::https://github.com/canonical/mimir-worker-k8s-operator//terraform"
  app_name   = var.meta_read_name
  model_name = var.model_name
  channel    = var.channel
  config = {
    role-read = true
  }
  units = var.meta_read_units
}

module "mimir_meta_write" {
  source     = "git::https://github.com/canonical/mimir-worker-k8s-operator//terraform"
  app_name   = var.meta_write_name
  model_name = var.model_name
  channel    = var.channel
  config = {
    role-write = true
  }
  units = var.meta_write_units
}

module "mimir_meta_backend" {
  source     = "git::https://github.com/canonical/mimir-worker-k8s-operator//terraform"
  app_name   = var.meta_backend_name
  model_name = var.model_name
  channel    = var.channel
  config = {
    role-backend = true
  }
  units = var.meta_backend_units
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

resource "juju_integration" "coordinator_to_meta_read" {
  model = var.model_name

  application {
    name     = module.mimir_coordinator.app_name
    endpoint = "mimir-cluster"
  }

  application {
    name     = module.mimir_meta_read.app_name
    endpoint = "mimir-cluster"
  }
}

resource "juju_integration" "coordinator_to_meta_write" {
  model = var.model_name

  application {
    name     = module.mimir_coordinator.app_name
    endpoint = "mimir-cluster"
  }

  application {
    name     = module.mimir_meta_write.app_name
    endpoint = "mimir-cluster"
  }
}

resource "juju_integration" "coordinator_to_meta_backend" {
  model = var.model_name

  application {
    name     = module.mimir_coordinator.app_name
    endpoint = "mimir-cluster"
  }

  application {
    name     = module.mimir_meta_backend.app_name
    endpoint = "mimir-cluster"
  }
}

# TODO: Replace s3_integrator resource to use its remote terraform module once available
resource "juju_application" "s3_integrator" {
  name = "mimir-s3-bucket"
  model = var.model_name
  trust = true

  charm {
    name    = "s3-integrator"
    channel = var.channel
  }
  units = 1

}

module "mimir_coordinator" {
  source     = "git::https://github.com/canonical/mimir-coordinator-k8s-operator//main"
  app_name   = "mimir"
  model_name = var.model_name
  channel    = var.channel
}

module "mimir_read" {
  source     = "git::https://github.com/canonical/mimir-worker-k8s-operator//main"
  app_name   = var.mimir_read_name
  model_name = var.model_name
  channel    = var.channel
  config = {
    role-all  = false
    role-read = true
  }
  units = var.mimir_read_units
}

module "mimir_write" {
  source     = "git::https://github.com/canonical/mimir-worker-k8s-operator//main"
  app_name   = var.mimir_write_name
  model_name = var.model_name
  channel    = var.channel
  config = {
    role-all   = false
    role-write = true
  }
  units = var.mimir_write_units
}

module "mimir_backend" {
  source     = "git::https://github.com/canonical/mimir-worker-k8s-operator//main"
  app_name   = var.mimir_backend_name
  model_name = var.model_name
  channel    = var.channel
  config = {
    role-all     = false
    role-backend = true
  }
  units = var.mimir_backend_units
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

resource "juju_integration" "coordinator_to_mimir_read" {
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

resource "juju_integration" "coordinator_to_mimir_write" {
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

resource "juju_integration" "coordinator_to_mimir_backend" {
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


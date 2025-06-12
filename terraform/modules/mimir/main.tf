resource "juju_secret" "mimir_s3_credentials_secret" {
  model = var.model
  name  = "mimir_s3_credentials"
  value = {
    access-key = var.s3_access_key
    secret-key = var.s3_secret_key
  }
  info = "Credentials for the S3 endpoint"
}

resource "juju_access_secret" "mimir_s3_secret_access" {
  model = var.model
  applications = [
    juju_application.s3_integrator.name
  ]
  secret_id = juju_secret.mimir_s3_credentials_secret.secret_id
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
    credentials = "secret:${juju_secret.mimir_s3_credentials_secret.secret_id}"
  }
  units = 1

}

module "mimir_coordinator" {
  source      = "git::https://github.com/canonical/mimir-coordinator-k8s-operator//terraform"
  app_name    = "mimir"
  model       = var.model
  channel     = var.channel
  revision    = var.coordinator_revision
  units       = var.coordinator_units
  constraints = var.anti_affinity ? "arch=amd64 tags=anti-pod.app.kubernetes.io/name=mimir,anti-pod.topology-key=kubernetes.io/hostname" : null
}

module "mimir_read" {
  source      = "git::https://github.com/canonical/mimir-worker-k8s-operator//terraform"
  app_name    = var.read_name
  model       = var.model
  channel     = var.channel
  revision    = var.worker_revision
  constraints = var.anti_affinity ? "arch=amd64 tags=anti-pod.app.kubernetes.io/name=${var.read_name},anti-pod.topology-key=kubernetes.io/hostname" : null
  config = {
    role-read = true
  }
  units = var.read_units
  depends_on = [
    module.mimir_coordinator
  ]
}

module "mimir_write" {
  source      = "git::https://github.com/canonical/mimir-worker-k8s-operator//terraform"
  app_name    = var.write_name
  model       = var.model
  channel     = var.channel
  revision    = var.worker_revision
  constraints = var.anti_affinity ? "arch=amd64 tags=anti-pod.app.kubernetes.io/name=${var.write_name},anti-pod.topology-key=kubernetes.io/hostname" : null
  config = {
    role-write = true
  }
  units = var.write_units
  depends_on = [
    module.mimir_coordinator
  ]
}

module "mimir_backend" {
  source      = "git::https://github.com/canonical/mimir-worker-k8s-operator//terraform"
  app_name    = var.backend_name
  model       = var.model
  channel     = var.channel
  revision    = var.worker_revision
  constraints = var.anti_affinity ? "arch=amd64 tags=anti-pod.app.kubernetes.io/name=${var.backend_name},anti-pod.topology-key=kubernetes.io/hostname" : null
  config = {
    role-backend = true
  }
  units = var.backend_units
  depends_on = [
    module.mimir_coordinator
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
    name     = module.mimir_coordinator.app_name
    endpoint = "s3"
  }
}

resource "juju_integration" "coordinator_to_read" {
  model = var.model

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
  model = var.model

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
  model = var.model

  application {
    name     = module.mimir_coordinator.app_name
    endpoint = "mimir-cluster"
  }

  application {
    name     = module.mimir_backend.app_name
    endpoint = "mimir-cluster"
  }
}

module "catalogue" {
  source     = "git::https://github.com/canonical/catalogue-k8s-operator//terraform"
  app_name   = "catalogue"
  model_name = var.model_name
  channel    = var.channel
}

module "grafana" {
  source     = "git::https://github.com/canonical/grafana-k8s-operator//terraform"
  app_name   = "grafana"
  model_name = var.model_name
  channel    = var.channel
}

module "loki" {
  source      = "git::https://github.com/canonical/observability//terraform/modules/loki"
  model_name  = var.model_name
  channel     = var.channel
}

module "mimir" {
  source      = "git::https://github.com/canonical/observability//terraform/modules/mimir"
  model_name  = var.model_name
  channel     = var.channel
}

module "ssc" {
  count      = var.use_tls ? 1 : 0
  source     = "git::https://github.com/canonical/self-signed-certificates-operator//terraform"
  model_name = var.model_name
  channel    = var.channel
}

module "tempo" {
  source      = "git::https://github.com/canonical/observability//terraform/modules/tempo?ref=feature/local_exec"
  model_name  = var.model_name
  channel     = var.channel
}

module "traefik" {
  source     = "git::https://github.com/canonical/traefik-k8s-operator//terraform"
  app_name   = "traefik"
  model_name = var.model_name
  channel    = var.channel
}

# -------------- # Integrations --------------

# Provided by Mimir

resource "juju_integration" "mimir-grafana-dashboards-provider" {
  model = var.model_name

  application {
    name     = module.mimir.app_names.mimir_coordinator
    endpoint = module.mimir.provides.grafana_dashboards_provider
  }

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.requires.grafana_dashboard
  }
}

resource "juju_integration" "mimir-grafana-source" {
  model = var.model_name

  application {
    name     = module.mimir.app_names.mimir_coordinator
    endpoint = module.mimir.provides.grafana_source
  }

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.requires.grafana_source
  }
}

# Provided by Loki

resource "juju_integration" "loki-grafana-dashboards-provider" {
  model = var.model_name

  application {
    name     = module.loki.app_names.loki_coordinator
    endpoint = module.loki.provides.grafana_dashboards_provider
  }

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.requires.grafana_dashboard
  }
}

resource "juju_integration" "loki-grafana-source" {
  model = var.model_name

  application {
    name     = module.loki.app_names.loki_coordinator
    endpoint = module.loki.provides.grafana_source
  }

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.requires.grafana_source
  }
}

# Provided by Tempo
resource "juju_integration" "tempo-grafana-source" {
  model = var.model_name

  application {
    name     = module.tempo.app_names.tempo_coordinator
    endpoint = module.tempo.provides.grafana_source
  }

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.requires.grafana_source
  }
}


# Provided by Catalogue

resource "juju_integration" "grafana-catalogue" {
  model = var.model_name

  application {
    name     = module.catalogue.app_name
    endpoint = module.catalogue.provides.catalogue
  }

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.requires.catalogue
  }
}

# Provided by Traefik

resource "juju_integration" "catalogue-ingress" {
  model = var.model_name

  application {
    name     = module.traefik.app_name
    endpoint = module.traefik.provides.ingress
  }

  application {
    name     = module.catalogue.app_name
    endpoint = module.catalogue.requires.ingress
  }
}

resource "juju_integration" "grafana-ingress" {
  model = var.model_name

  application {
    name     = module.traefik.app_name
    endpoint = module.traefik.provides.traefik_route
  }

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.requires.ingress
  }
}

resource "juju_integration" "loki-ingress" {
  model = var.model_name

  application {
    name     = module.traefik.app_name
    endpoint = module.traefik.provides.ingress
  }

  application {
    name     = module.loki.app_names.loki_coordinator
    endpoint = module.loki.requires.ingress
  }
}

resource "null_resource" "s3fix" {

  provisioner "local-exec" {
    # There's currently no way to wait for the charm to be idle, hence the sleep
    # https://github.com/juju/terraform-provider-juju/issues/202
    command = <<-EOT
      sleep 600;

      juju ssh -m cos minio/leader curl https://dl.min.io/client/mc/release/linux-amd64/mc --create-dirs -o '/root/minio/mc';
      juju ssh -m cos minio/leader chmod +x '/root/minio/mc';
      juju ssh -m cos minio/leader /root/minio/mc alias set local http://minio-0.minio-endpoints.cos.svc.cluster.local:9000 user password;
      juju ssh -m cos minio/leader /root/minio/mc mb local/mimir;
      juju ssh -m cos minio/leader /root/minio/mc mb local/loki;
      juju ssh -m cos minio/leader /root/minio/mc mb local/tempo;

      juju config loki-s3-bucket endpoint="http://minio-0.minio-endpoints.cos.svc.cluster.local:9000" bucket="loki";
      juju config mimir-s3-bucket endpoint="http://minio-0.minio-endpoints.cos.svc.cluster.local:9000" bucket="mimir";
      juju config tempo-s3-bucket endpoint="http://minio-0.minio-endpoints.cos.svc.cluster.local:9000" bucket="tempo";

      juju run -m cos loki-s3-bucket/leader sync-s3-credentials access-key=user secret-key=password;
      juju run -m cos mimir-s3-bucket/leader sync-s3-credentials access-key=user secret-key=password;
      juju run -m cos tempo-s3-bucket/leader sync-s3-credentials access-key=user secret-key=password;
      
      sleep 30"
    EOT
  }
}

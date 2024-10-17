module "catalogue" {
  source     = "git::https://github.com/canonical/catalogue-k8s-operator//terraform?ref=feature/terraform"
  app_name   = "catalogue"
  model_name = var.model_name
  channel    = var.channel
}

module "grafana" {
  source     = "git::https://github.com/canonical/grafana-k8s-operator//terraform?ref=feature/terraform"
  app_name   = "grafana"
  model_name = var.model_name
  channel    = var.channel
}

module "loki" {
  source      = "git::https://github.com/canonical/observability//terraform/modules/loki?ref=cos-ha"
  model_name  = var.model_name
  channel     = var.channel
}

module "mimir" {
  source      = "git::https://github.com/canonical/observability//terraform/modules/mimir?ref=cos-ha"
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
  source      = "git::https://github.com/canonical/observability//terraform/modules/tempo?ref=cos-ha"
  model_name  = var.model_name
  channel     = var.channel
}

module "traefik" {
  source     = "git::https://github.com/canonical/traefik-k8s-operator//terraform?ref=feature/terraform"
  app_name   = "traefik"
  model_name = var.model_name
  channel    = var.channel
}

# -------------- # Integrations --------------

# Provided by Loki

resource "juju_integration" "loki-grafana-dashboard-provider" {
  model = var.model_name

  application {
    name     = module.loki.app_names.loki_coordinator
    endpoint = module.loki.grafana_dashboard_provider_endpoint
  }

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.grafana_dashboard_endpoint
  }
}

resource "juju_integration" "loki-grafana-source" {
  model = var.model_name

  application {
    name     = module.loki.app_names.loki_coordinator
    endpoint = module.loki.grafana_source_endpoint
  }

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.grafana_source_endpoint
  }
}

# Provided by Catalogue

resource "juju_integration" "grafana-catalogue" {
  model = var.model_name

  application {
    name     = module.catalogue.app_name
    endpoint = module.catalogue.catalogue_endpoint
  }

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.catalogue_endpoint
  }
}

# Provided by Traefik

resource "juju_integration" "catalogue-ingress" {
  model = var.model_name

  application {
    name     = module.traefik.app_name
    endpoint = module.traefik.ingress_endpoint
  }

  application {
    name     = module.catalogue.app_name
    endpoint = module.catalogue.ingress_endpoint
  }
}

resource "juju_integration" "grafana-ingress" {
  model = var.model_name

  application {
    name     = module.traefik.app_name
    endpoint = module.traefik.traefik_route_endpoint
  }

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.ingress_endpoint
  }
}

resource "juju_integration" "loki-ingress" {
  model = var.model_name

  application {
    name     = module.traefik.app_name
    endpoint = module.traefik.ingress_per_unit_endpoint
  }

  application {
    name     = module.loki.app_names.loki_coordinator
    endpoint = module.loki.ingress_endpoint
  }
}

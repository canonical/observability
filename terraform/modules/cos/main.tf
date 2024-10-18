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

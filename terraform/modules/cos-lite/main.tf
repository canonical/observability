# -------------- # Applications --------------

module "ssc" {
  count   = var.use_tls ? 1 : 0
  source  = "git::https://github.com/canonical/self-signed-certificates-operator//terraform"
  model   = var.model_name
  channel = var.channel
}

module "alertmanager" {
  source     = "git::https://github.com/canonical/alertmanager-k8s-operator//terraform"
  app_name   = "alertmanager"
  model_name = var.model_name
  channel    = var.channel
}

module "catalogue" {
  source     = "git::https://github.com/canonical/catalogue-k8s-operator//terraform"
  app_name   = "catalogue"
  model_name = var.model_name
  channel    = var.channel
}

module "prometheus" {
  source     = "git::https://github.com/canonical/prometheus-k8s-operator//terraform"
  app_name   = "prometheus"
  model_name = var.model_name
  channel    = var.channel
}

module "loki" {
  source     = "git::https://github.com/canonical/loki-k8s-operator//terraform"
  app_name   = "loki"
  model_name = var.model_name
  channel    = var.channel
}

module "grafana" {
  source     = "git::https://github.com/canonical/grafana-k8s-operator//terraform"
  app_name   = "grafana"
  model_name = var.model_name
  channel    = var.channel
}

module "traefik" {
  source     = "git::https://github.com/canonical/traefik-k8s-operator//terraform"
  app_name   = "traefik"
  model_name = var.model_name
  channel    = var.channel
}


# -------------- # Integrations --------------


# Provided by Alertmanager

resource "juju_integration" "alertmanager_grafana_dashboards" {
  model = var.model_name

  application {
    name     = module.alertmanager.app_name
    endpoint = module.alertmanager.endpoints.grafana_dashboard
  }

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.endpoints.grafana_dashboard
  }
}

resource "juju_integration" "alertmanager_prometheus" {
  model = var.model_name

  application {
    name     = module.prometheus.app_name
    endpoint = module.prometheus.endpoints.alertmanager
  }

  application {
    name     = module.alertmanager.app_name
    endpoint = module.alertmanager.endpoints.alerting
  }
}

resource "juju_integration" "alertmanager_self_monitoring_prometheus" {
  model = var.model_name

  application {
    name     = module.prometheus.app_name
    endpoint = module.prometheus.endpoints.metrics_endpoint
  }

  application {
    name     = module.alertmanager.app_name
    endpoint = module.alertmanager.endpoints.self_metrics_endpoint
  }
}

resource "juju_integration" "alertmanager_loki" {
  model = var.model_name

  application {
    name     = module.loki.app_name
    endpoint = module.loki.endpoints.alertmanager
  }

  application {
    name     = module.alertmanager.app_name
    endpoint = module.alertmanager.endpoints.alerting
  }
}


resource "juju_integration" "grafana_source_alertmanager" {
  model = var.model_name

  application {
    name     = module.alertmanager.app_name
    endpoint = module.alertmanager.endpoints.grafana_source
  }

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.endpoints.grafana_source
  }
}

# Provided by Grafana

resource "juju_integration" "grafana_self_monitoring_prometheus" {
  model = var.model_name

  application {
    name     = module.prometheus.app_name
    endpoint = module.prometheus.endpoints.metrics_endpoint
  }

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.endpoints.metrics_endpoint
  }
}


# Provided by Prometheus

resource "juju_integration" "prometheus_grafana_dashboards_provider" {
  model = var.model_name

  application {
    name     = module.prometheus.app_name
    endpoint = module.prometheus.endpoints.grafana_dashboard
  }

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.endpoints.grafana_dashboard
  }
}

resource "juju_integration" "prometheus_grafana_source" {
  model = var.model_name

  application {
    name     = module.prometheus.app_name
    endpoint = module.prometheus.endpoints.grafana_source
  }

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.endpoints.grafana_source
  }
}




# Provided by Loki

resource "juju_integration" "loki_grafana_dashboards_provider" {
  model = var.model_name

  application {
    name     = module.loki.app_name
    endpoint = module.loki.endpoints.grafana_dashboard
  }

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.endpoints.grafana_dashboard
  }
}

resource "juju_integration" "loki_grafana_source" {
  model = var.model_name

  application {
    name     = module.loki.app_name
    endpoint = module.loki.endpoints.grafana_source
  }

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.endpoints.grafana_source
  }
}

resource "juju_integration" "loki_self_monitoring_prometheus" {
  model = var.model_name

  application {
    name     = module.prometheus.app_name
    endpoint = module.prometheus.endpoints.metrics_endpoint
  }

  application {
    name     = module.loki.app_name
    endpoint = module.loki.endpoints.metrics_endpoint
  }
}


# Provided by Catalogue

resource "juju_integration" "catalogue_alertmanager" {
  model = var.model_name

  application {
    name     = module.catalogue.app_name
    endpoint = module.catalogue.endpoints.catalogue
  }

  application {
    name     = module.alertmanager.app_name
    endpoint = module.alertmanager.endpoints.catalogue
  }
}

resource "juju_integration" "catalogue_grafana" {
  model = var.model_name

  application {
    name     = module.catalogue.app_name
    endpoint = module.catalogue.endpoints.catalogue
  }

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.endpoints.catalogue
  }
}

resource "juju_integration" "catalogue_prometheus" {
  model = var.model_name

  application {
    name     = module.catalogue.app_name
    endpoint = module.catalogue.endpoints.catalogue
  }

  application {
    name     = module.prometheus.app_name
    endpoint = module.prometheus.endpoints.catalogue
  }
}


# Provided by Traefik

resource "juju_integration" "alertmanager_ingress" {
  model = var.model_name

  application {
    name     = module.traefik.app_name
    endpoint = module.traefik.endpoints.ingress
  }

  application {
    name     = module.alertmanager.app_name
    endpoint = module.alertmanager.endpoints.ingress
  }
}


resource "juju_integration" "catalogue_ingress" {
  model = var.model_name

  application {
    name     = module.traefik.app_name
    endpoint = module.traefik.endpoints.ingress
  }

  application {
    name     = module.catalogue.app_name
    endpoint = module.catalogue.endpoints.ingress
  }
}

resource "juju_integration" "grafana_ingress" {
  model = var.model_name

  application {
    name     = module.traefik.app_name
    endpoint = module.traefik.endpoints.traefik_route
  }

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.endpoints.ingress
  }
}

resource "juju_integration" "prometheus_ingress" {
  model = var.model_name

  application {
    name     = module.traefik.app_name
    endpoint = module.traefik.endpoints.ingress_per_unit
  }

  application {
    name     = module.prometheus.app_name
    endpoint = module.prometheus.endpoints.ingress
  }
}

resource "juju_integration" "loki_ingress" {
  model = var.model_name

  application {
    name     = module.traefik.app_name
    endpoint = module.traefik.endpoints.ingress_per_unit
  }

  application {
    name     = module.loki.app_name
    endpoint = module.loki.endpoints.ingress
  }
}

resource "juju_integration" "traefik_self_monitoring_prometheus" {
  model = var.model_name

  application {
    name     = module.prometheus.app_name
    endpoint = module.prometheus.endpoints.metrics_endpoint
  }

  application {
    name     = module.traefik.app_name
    endpoint = module.traefik.endpoints.metrics_endpoint
  }
}

# -------------- # Offers --------------

resource "juju_offer" "alertmanager-karma-dashboard" {
  name             = "alertmanager-karma-dashboard"
  model            = var.model_name
  application_name = module.alertmanager.app_name
  endpoint         = "karma-dashboard"
}

resource "juju_offer" "grafana-dashboards" {
  name             = "grafana-dashboards"
  model            = var.model_name
  application_name = module.grafana.app_name
  endpoint         = "grafana-dashboard"
}

resource "juju_offer" "loki-logging" {
  name             = "loki-logging"
  model            = var.model_name
  application_name = module.loki.app_name
  endpoint         = "logging"
}

resource "juju_offer" "prometheus-receive-remote-write" {
  name             = "prometheus-receive-remote-write"
  model            = var.model_name
  application_name = module.prometheus.app_name
  endpoint         = "receive-remote-write"
}

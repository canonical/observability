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

module "grafana_agent" {
  source     = "git::https://github.com/canonical/grafana-agent-k8s-operator//terraform"
  app_name   = "grafana-agent"
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

resource "juju_integration" "agent_alertmanager_metrics" {
  model = var.model_name

  application {
    name     = module.alertmanager.app_name
    endpoint = module.alertmanager.endpoints.self_metrics_endpoint
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.requires.metrics_endpoint
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


# Provided by Mimir

resource "juju_integration" "prometheus_grafana_dashboards_provider" {
  model = var.model_name

  application {
    name     = module.prometheus.app_name
    endpoint = module.prometheus.endpoints.grafana_dashboards_provider
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

resource "juju_integration" "prometheus_tracing_grafana_agent_traicing_provider" {
  model = var.model_name

  application {
    name     = module.prometheus.app_name
    endpoint = module.prometheus.endpoints.charm_tracing
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.provides.tracing_provider
  }
}


resource "juju_integration" "prometheus_self_metrics_endpoint_grafana_agent_metrics_endpoint" {
  model = var.model_name

  application {
    name     = module.prometheus.app_name
    endpoint = module.prometheus.endpoints.self_metrics_endpoint
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.requires.metrics_endpoint
  }
}


# Provided by Loki

resource "juju_integration" "loki_grafana_dashboards_provider" {
  model = var.model_name

  application {
    name     = module.loki.app_name
    endpoint = module.loki.endpoints.grafana_dashboards_provider
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

resource "juju_integration" "loki_logging_consumer_grafana_agent_logging_provider" {
  model = var.model_name

  application {
    name     = module.loki.app_name
    endpoint = module.loki.endpoints.logging_consumer
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.provides.logging_provider
  }
}

resource "juju_integration" "loki_logging_grafana_agent_logging_consumer" {
  model = var.model_name

  application {
    name     = module.loki.app_name
    endpoint = module.loki.endpoints.logging
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.requires.logging_consumer
  }
}

resource "juju_integration" "loki_tracing_grafana_agent_traicing_provider" {
  model = var.model_name

  application {
    name     = module.loki.app_name
    endpoint = module.loki.endpoints.charm_tracing
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.provides.tracing_provider
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
    name     = module.mimir.app_names.prometheus
    endpoint = module.mimir.endpoints.catalogue
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
    endpoint = module.traefik.endpoints.ingress
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
    endpoint = module.traefik.endpoints.ingress
  }

  application {
    name     = module.loki.app_name
    endpoint = module.loki.endpoints.ingress
  }
}


# Grafana agent

resource "juju_integration" "agent_loki_metrics" {
  model = var.model_name

  application {
    name     = module.loki.app_name
    endpoint = module.loki.endpoints.self_metrics_endpoint
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.requires.metrics_endpoint
  }
}

resource "juju_integration" "agent_prometheus_metrics" {
  model = var.model_name

  application {
    name     = module.prometheus.app_name
    endpoint = module.prometheus.endpoints.receive_remote_write
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.requires.send_remote_write
  }
}
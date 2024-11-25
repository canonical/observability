# -------------- # Applications --------------

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
  source     = "git::https://github.com/canonical/observability//terraform/modules/loki?ref=self-monitoring"
  model_name = var.model_name
  channel    = var.channel
}

module "mimir" {
  source     = "git::https://github.com/canonical/observability//terraform/modules/mimir?ref=self-monitoring"
  model_name = var.model_name
  channel    = var.channel
}

module "ssc" {
  count      = var.use_tls ? 1 : 0
  source     = "git::https://github.com/canonical/self-signed-certificates-operator//terraform"
  model_name = var.model_name
  channel    = var.channel
}

module "tempo" {
  source     = "git::https://github.com/canonical/observability//terraform/modules/tempo?ref=self-monitoring"
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

module "s3" {
  source         = "git::https://github.com/canonical/observability//terraform/modules/s3"
  model_name     = var.model_name
  channel        = var.channel
  minio_user     = var.minio_user
  minio_password = var.minio_password

  loki  = module.loki
  mimir = module.mimir
  tempo = module.tempo
}

# -------------- # Integrations --------------

# Provided by Mimir

resource "juju_integration" "mimir-grafana-dashboards-provider" {
  model = var.model_name

  application {
    name     = module.mimir.app_names.mimir_coordinator
    endpoint = module.mimir.endpoints.grafana_dashboards_provider
  }

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.endpoints.grafana_dashboard
  }
}

resource "juju_integration" "mimir-grafana-source" {
  model = var.model_name

  application {
    name     = module.mimir.app_names.mimir_coordinator
    endpoint = module.mimir.endpoints.grafana_source
  }

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.endpoints.grafana_source
  }
}

resource "juju_integration" "mimir-tracing-grafana-agent-traicing-provider" {
  model = var.model_name

  application {
    name     = module.mimir.app_names.mimir_coordinator
    endpoint = module.mimir.endpoints.charm_tracing
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.provides.tracing_provider
  }
}


resource "juju_integration" "mimir-self_metrics_endpoint-grafana-agent-metrics_endpoint" {
  model = var.model_name

  application {
    name     = module.mimir.app_names.mimir_coordinator
    endpoint = module.mimir.endpoints.self_metrics_endpoint
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.requires.metrics_endpoint
  }
}


# Provided by Loki

resource "juju_integration" "loki-grafana-dashboards-provider" {
  model = var.model_name

  application {
    name     = module.loki.app_names.loki_coordinator
    endpoint = module.loki.endpoints.grafana_dashboards_provider
  }

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.endpoints.grafana_dashboard
  }
}

resource "juju_integration" "loki-grafana-source" {
  model = var.model_name

  application {
    name     = module.loki.app_names.loki_coordinator
    endpoint = module.loki.endpoints.grafana_source
  }

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.endpoints.grafana_source
  }
}

resource "juju_integration" "loki-logging-consumer-grafana-agent-logging-provider" {
  model = var.model_name

  application {
    name     = module.loki.app_names.loki_coordinator
    endpoint = module.loki.endpoints.logging_consumer
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.provides.logging_provider
  }
}

resource "juju_integration" "loki-logging-grafana-agent-logging-consumer" {
  model = var.model_name

  application {
    name     = module.loki.app_names.loki_coordinator
    endpoint = module.loki.endpoints.logging
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.requires.logging_consumer
  }
}

resource "juju_integration" "loki-tracing-grafana-agent-traicing-provider" {
  model = var.model_name

  application {
    name     = module.loki.app_names.loki_coordinator
    endpoint = module.loki.endpoints.charm_tracing
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.provides.tracing_provider
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
    endpoint = module.grafana.endpoints.grafana_source
  }
}


resource "juju_integration" "tempo-tracing-grafana-agent-tracing" {
  model = var.model_name

  application {
    name     = module.tempo.app_names.tempo_coordinator
    endpoint = module.tempo.provides.tracing
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.requires.tracing
  }
}

resource "juju_integration" "tempo-metrics_endpoint-grafana-agent-metrics_endpoint" {
  model = var.model_name

  application {
    name     = module.tempo.app_names.tempo_coordinator
    endpoint = module.tempo.provides.metrics_endpoint
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.requires.metrics_endpoint
  }
}

resource "juju_integration" "tempo-logging-grafana-agent-logging-provider" {
  model = var.model_name

  application {
    name     = module.tempo.app_names.tempo_coordinator
    endpoint = module.tempo.requires.logging
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.provides.logging_provider
  }
}

# Provided by Catalogue

resource "juju_integration" "grafana-catalogue" {
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

# Provided by Traefik

resource "juju_integration" "catalogue-ingress" {
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

resource "juju_integration" "grafana-ingress" {
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

resource "juju_integration" "loki-ingress" {
  model = var.model_name

  application {
    name     = module.traefik.app_name
    endpoint = module.traefik.endpoints.ingress
  }

  application {
    name     = module.loki.app_names.loki_coordinator
    endpoint = module.loki.endpoints.ingress
  }
}

# Grafana agent

resource "juju_integration" "agent-loki-metrics" {
  model = var.model_name

  application {
    name     = module.loki.app_names.loki_coordinator
    endpoint = module.loki.endpoints.self_metrics_endpoint
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.requires.metrics_endpoint
  }
}

resource "juju_integration" "agent-mimir-metrics" {
  model = var.model_name

  application {
    name     = module.mimir.app_names.mimir_coordinator
    endpoint = module.mimir.endpoints.receive_remote_write
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.requires.send_remote_write
  }
}

# Provided by Grafana

resource "juju_integration" "grafana-tracing-grafana-agent-traicing-provider" {
  model = var.model_name

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.endpoints.tracing
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.provides.tracing_provider
  }
}
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
  source     = "git::https://github.com/canonical/observability//terraform/modules/loki"
  model_name = var.model_name
  channel    = var.channel
}

module "mimir" {
  source     = "git::https://github.com/canonical/observability//terraform/modules/mimir"
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
  source     = "git::https://github.com/canonical/observability//terraform/modules/tempo"
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

resource "juju_integration" "mimir_grafana_dashboards_provider" {
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

resource "juju_integration" "mimir_grafana_source" {
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

resource "juju_integration" "mimir_tracing_grafana_agent_traicing_provider" {
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


resource "juju_integration" "mimir_self_metrics_endpoint_grafana_agent_metrics_endpoint" {
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

resource "juju_integration" "loki_grafana_dashboards_provider" {
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

resource "juju_integration" "loki_grafana_source" {
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

resource "juju_integration" "loki_logging_consumer_grafana_agent_logging_provider" {
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

resource "juju_integration" "loki_logging_grafana_agent_logging_consumer" {
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

resource "juju_integration" "loki_tracing_grafana_agent_traicing_provider" {
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
resource "juju_integration" "tempo_grafana_source" {
  model = var.model_name

  application {
    name     = module.tempo.app_names.tempo_coordinator
    endpoint = module.tempo.endpoints.grafana_source
  }

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.endpoints.grafana_source
  }
}


resource "juju_integration" "tempo_tracing_grafana_agent_tracing" {
  model = var.model_name

  application {
    name     = module.tempo.app_names.tempo_coordinator
    endpoint = module.tempo.endpoints.tracing
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.requires.tracing
  }
}

resource "juju_integration" "tempo_metrics_endpoint_grafana_agent_metrics_endpoint" {
  model = var.model_name

  application {
    name     = module.tempo.app_names.tempo_coordinator
    endpoint = module.tempo.endpoints.metrics_endpoint
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.requires.metrics_endpoint
  }
}

resource "juju_integration" "tempo_logging_grafana_agent_logging_provider" {
  model = var.model_name

  application {
    name     = module.tempo.app_names.tempo_coordinator
    endpoint = module.tempo.endpoints.logging
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.provides.logging_provider
  }
}

resource "juju_integration" "tempo_send_remote_write_mimir_receive_remote_write" {
  model = var.model_name

  application {
    name     = module.tempo.app_names.tempo_coordinator
    endpoint = module.tempo.endpoints.send-remote-write
  }

  application {
    name     = module.mimir.app_names.mimir_coordinator
    endpoint = module.mimir.endpoints.receive_remote_write
  }
}

# Provided by Catalogue

resource "juju_integration" "grafana_catalogue" {
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

resource "juju_integration" "loki_ingress" {
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

resource "juju_integration" "agent_loki_metrics" {
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

resource "juju_integration" "agent_mimir_metrics" {
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

resource "juju_integration" "grafana_tracing_grafana_agent_traicing_provider" {
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
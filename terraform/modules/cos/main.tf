# -------------- # Applications --------------

module "alertmanager" {
  source     = "git::https://github.com/canonical/alertmanager-k8s-operator//terraform"
  app_name   = "alertmanager"
  model      = var.model
  channel    = var.channel
}

module "catalogue" {
  source     = "git::https://github.com/canonical/catalogue-k8s-operator//terraform"
  app_name   = "catalogue"
  model      = var.model
  channel    = var.channel
}

module "grafana" {
  source     = "git::https://github.com/canonical/grafana-k8s-operator//terraform"
  app_name   = "grafana"
  model_name = var.model
  channel    = var.channel
}

module "loki" {
  source            = "git::https://github.com/canonical/observability//terraform/modules/loki?ref=fix-variable-name-changes"
  model             = var.model
  channel           = var.channel
  backend_units     = var.loki_backend_units
  read_units        = var.loki_read_units
  write_units       = var.loki_write_units
  coordinator_units = var.loki_coordinator_units
  s3_bucket         = var.loki_bucket
  s3_endpoint       = var.s3_endpoint
  s3_password       = var.s3_password
  s3_user           = var.s3_user
  anti_affinity     = var.anti_affinity
}

module "mimir" {
  source            = "git::https://github.com/canonical/observability//terraform/modules/mimir?ref=fix-variable-name-changes"
  model             = var.model
  channel           = var.channel
  backend_units     = var.mimir_backend_units
  read_units        = var.mimir_read_units
  write_units       = var.mimir_write_units
  coordinator_units = var.mimir_coordinator_units
  s3_bucket         = var.mimir_bucket
  s3_endpoint       = var.s3_endpoint
  s3_password       = var.s3_password
  s3_user           = var.s3_user
  anti_affinity     = var.anti_affinity
}

module "ssc" {
  count         = var.use_tls ? 1 : 0
  source        = "git::https://github.com/canonical/self-signed-certificates-operator//terraform"
  model         = var.model
  channel       = var.ssc_channel
}

module "tempo" {
  source                  = "git::https://github.com/canonical/observability//terraform/modules/tempo?ref=fix-variable-name-changes"
  model                   = var.model
  channel                 = var.channel
  coordinator_units       = var.tempo_coordinator_units
  querier_units           = var.tempo_querier_units
  query_frontend_units    = var.tempo_query_frontend_units
  ingester_units          = var.tempo_ingester_units
  distributor_units       = var.tempo_distributor_units
  compactor_units         = var.tempo_compactor_units
  metrics_generator_units = var.tempo_metrics_generator_units
  s3_bucket               = var.tempo_bucket
  s3_endpoint             = var.s3_endpoint
  s3_password             = var.s3_password
  s3_user                 = var.s3_user
  anti_affinity           = var.anti_affinity
}

module "traefik" {
  source     = "git::https://github.com/canonical/traefik-k8s-operator//terraform"
  app_name   = "traefik"
  model_name = var.model
  channel    = var.traefik_channel
  config     = var.cloud == "aws" ? { "loadbalancer_annotations" = "service.beta.kubernetes.io/aws-load-balancer-scheme=internet-facing" } : {}
}

module "grafana_agent" {
  source     = "git::https://github.com/canonical/grafana-agent-k8s-operator//terraform"
  app_name   = "grafana-agent"
  model      = var.model
  channel    = var.channel
}



# -------------- # Integrations --------------

# Provided by Alertmanager

resource "juju_integration" "alertmanager_grafana_dashboards" {
  model = var.model

  application {
    name     = module.alertmanager.app_name
    endpoint = module.alertmanager.endpoints.grafana_dashboard
  }

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.endpoints.grafana_dashboard
  }
}

resource "juju_integration" "mimir_alertmanager" {
  model = var.model

  application {
    name     = module.mimir.app_names.mimir_coordinator
    endpoint = module.mimir.endpoints.alertmanager
  }

  application {
    name     = module.alertmanager.app_name
    endpoint = module.alertmanager.endpoints.alerting
  }
}

resource "juju_integration" "loki_alertmanager" {
  model = var.model

  application {
    name     = module.loki.app_names.loki_coordinator
    endpoint = module.loki.endpoints.alertmanager
  }

  application {
    name     = module.alertmanager.app_name
    endpoint = module.alertmanager.endpoints.alerting
  }
}

resource "juju_integration" "agent_alertmanager_metrics" {
  model = var.model

  application {
    name     = module.alertmanager.app_name
    endpoint = module.alertmanager.endpoints.self_metrics_endpoint
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.endpoints.metrics_endpoint
  }
}

resource "juju_integration" "grafana_source_alertmanager" {
  model = var.model

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

resource "juju_integration" "mimir_grafana_dashboards_provider" {
  model = var.model

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
  model = var.model

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
  model = var.model

  application {
    name     = module.mimir.app_names.mimir_coordinator
    endpoint = module.mimir.endpoints.charm_tracing
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.endpoints.tracing_provider
  }
}


resource "juju_integration" "mimir_self_metrics_endpoint_grafana_agent_metrics_endpoint" {
  model = var.model

  application {
    name     = module.mimir.app_names.mimir_coordinator
    endpoint = module.mimir.endpoints.self_metrics_endpoint
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.endpoints.metrics_endpoint
  }
}


# Provided by Loki

resource "juju_integration" "loki_grafana_dashboards_provider" {
  model = var.model

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
  model = var.model

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
  model = var.model

  application {
    name     = module.loki.app_names.loki_coordinator
    endpoint = module.loki.endpoints.logging_consumer
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.endpoints.logging_provider
  }
}

resource "juju_integration" "loki_logging_grafana_agent_logging_consumer" {
  model = var.model

  application {
    name     = module.loki.app_names.loki_coordinator
    endpoint = module.loki.endpoints.logging
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.endpoints.logging_consumer
  }
}

resource "juju_integration" "loki_tracing_grafana_agent_traicing_provider" {
  model = var.model

  application {
    name     = module.loki.app_names.loki_coordinator
    endpoint = module.loki.endpoints.charm_tracing
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.endpoints.tracing_provider
  }
}

# Provided by Tempo
resource "juju_integration" "tempo_grafana_source" {
  model = var.model

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
  model = var.model

  application {
    name     = module.tempo.app_names.tempo_coordinator
    endpoint = module.tempo.endpoints.tracing
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.endpoints.tracing
  }
}

resource "juju_integration" "tempo_metrics_endpoint_grafana_agent_metrics_endpoint" {
  model = var.model

  application {
    name     = module.tempo.app_names.tempo_coordinator
    endpoint = module.tempo.endpoints.metrics_endpoint
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.endpoints.metrics_endpoint
  }
}

resource "juju_integration" "tempo_logging_grafana_agent_logging_provider" {
  model = var.model

  application {
    name     = module.tempo.app_names.tempo_coordinator
    endpoint = module.tempo.endpoints.logging
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.endpoints.logging_provider
  }
}

resource "juju_integration" "tempo_send_remote_write_mimir_receive_remote_write" {
  model = var.model

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

resource "juju_integration" "alertmanager_catalogue" {
  model = var.model

  application {
    name     = module.catalogue.app_name
    endpoint = module.catalogue.endpoints.catalogue
  }

  application {
    name     = module.alertmanager.app_name
    endpoint = module.alertmanager.endpoints.catalogue
  }
}

resource "juju_integration" "grafana_catalogue" {
  model = var.model

  application {
    name     = module.catalogue.app_name
    endpoint = module.catalogue.endpoints.catalogue
  }

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.endpoints.catalogue
  }
}

resource "juju_integration" "tempo_catalogue" {
  model = var.model

  application {
    name     = module.catalogue.app_name
    endpoint = module.catalogue.endpoints.catalogue
  }

  application {
    name     = module.tempo.app_names.tempo_coordinator
    endpoint = module.tempo.endpoints.catalogue
  }
}

resource "juju_integration" "mimir_catalogue" {
  model = var.model

  application {
    name     = module.catalogue.app_name
    endpoint = module.catalogue.endpoints.catalogue
  }

  application {
    name     = module.mimir.app_names.mimir_coordinator
    endpoint = module.mimir.endpoints.catalogue
  }
}

# Provided by Traefik

resource "juju_integration" "alertmanager_ingress" {
  model = var.model

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
  model = var.model

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
  model = var.model

  application {
    name     = module.traefik.app_name
    endpoint = module.traefik.endpoints.traefik_route
  }

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.endpoints.ingress
  }
}

resource "juju_integration" "mimir_ingress" {
  model = var.model

  application {
    name     = module.traefik.app_name
    endpoint = module.traefik.endpoints.ingress
  }

  application {
    name     = module.mimir.app_names.mimir_coordinator
    endpoint = module.mimir.endpoints.ingress
  }
}

resource "juju_integration" "loki_ingress" {
  model = var.model

  application {
    name     = module.traefik.app_name
    endpoint = module.traefik.endpoints.ingress
  }

  application {
    name     = module.loki.app_names.loki_coordinator
    endpoint = module.loki.endpoints.ingress
  }
}

resource "juju_integration" "tempo_ingress" {
  model = var.model

  application {
    name     = module.traefik.app_name
    endpoint = module.traefik.endpoints.traefik_route
  }

  application {
    name     = module.tempo.app_names.tempo_coordinator
    endpoint = module.tempo.endpoints.ingress
  }
}

# Grafana agent

resource "juju_integration" "agent_loki_metrics" {
  model = var.model

  application {
    name     = module.loki.app_names.loki_coordinator
    endpoint = module.loki.endpoints.self_metrics_endpoint
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.endpoints.metrics_endpoint
  }
}

resource "juju_integration" "agent_mimir_metrics" {
  model = var.model

  application {
    name     = module.mimir.app_names.mimir_coordinator
    endpoint = module.mimir.endpoints.receive_remote_write
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.endpoints.send_remote_write
  }
}

# Provided by Grafana

resource "juju_integration" "grafana_tracing_grafana_agent_traicing_provider" {
  model = var.model

  application {
    name     = module.grafana.app_name
    endpoint = module.grafana.endpoints.charm_tracing
  }

  application {
    name     = module.grafana_agent.app_name
    endpoint = module.grafana_agent.endpoints.tracing_provider
  }
}

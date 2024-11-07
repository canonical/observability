output "app_names" {
  value = merge(
    {
      loki_s3_integrator = juju_application.s3_integrator.name,
      loki_coordinator   = module.loki_coordinator.app_name,
      loki_backend       = module.loki_backend.app_name,
      loki_read          = module.loki_read.app_name,
      loki_write         = module.loki_write.app_name,
    }
  )
}

output "requires" {
  value = {
    alertmanager     = "alertmanager",
    certificates     = "certificates",
    ingress          = "ingress",
    logging_consumer = "logging-consumer",
    s3               = "s3",
    tracing          = "tracing",
  }
}

output "provides" {
  value = {
    grafana_dashboards_provider = "grafana-dashboards-provider",
    grafana_source              = "grafana-source",
    logging                     = "logging",
    loki_cluster                = "loki-cluster",
    receive_remote_write        = "receive-remote-write",
    self_metrics_endpoint       = "self-metrics-endpoint",
  }
}

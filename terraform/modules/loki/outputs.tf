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

output "endpoints" {
  value = {
    alertmanager                = "alertmanager",
    certificates                = "certificates",
    grafana_dashboards_provider = "grafana-dashboards-provider",
    grafana_source              = "grafana-source",
    ingress                     = "ingress",
    logging                     = "logging",
    logging_consumer            = "logging-consumer",
    loki_cluster                = "loki-cluster",
    receive_remote_write        = "receive-remote-write",
    s3                          = "s3",
    self_metrics_endpoint       = "self-metrics-endpoint",
    tracing                     = "tracing",
  }
}

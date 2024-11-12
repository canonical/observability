output "app_names" {
  value = merge(
    {
      mimir_s3_integrator = juju_application.s3_integrator.name,
      mimir_coordinator   = module.mimir_coordinator.app_name,
      mimir_read          = module.mimir_meta_read.app_name,
      mimir_write         = module.mimir_meta_write.app_name,
      mimir_backend       = module.mimir_meta_backend.app_name,
    }
  )
}

output "requires" {
  value = {
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
    mimir_cluster               = "mimir-cluster",
    receive_remote_write        = "receive-remote-write",
    self_metrics_endpoint       = "self-metrics-endpoint",
  }
}
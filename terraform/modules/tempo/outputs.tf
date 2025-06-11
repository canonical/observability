output "app_names" {
  value = merge(
    {
      tempo_s3_integrator     = juju_application.s3_integrator.name,
      tempo_coordinator       = module.tempo_coordinator.app_name,
      tempo_querier           = module.tempo_querier.app_name,
      tempo_query_frontend    = module.tempo_query_frontend.app_name,
      tempo_ingester          = module.tempo_ingester.app_name,
      tempo_distributor       = module.tempo_distributor.app_name,
      tempo_compactor         = module.tempo_compactor.app_name,
      tempo_metrics_generator = module.tempo_metrics_generator.app_name,
    }
  )
}

output "endpoints" {
  value = {
    # Requires
    logging            = "logging",
    ingress            = "ingress",
    certificates       = "certificates",
    send-remote-write  = "send-remote-write",
    receive_datasource = "receive-datasource"
    catalogue          = "catalogue",

    # Provides
    tempo_cluster     = "tempo-cluster"
    grafana_dashboard = "grafana-dashboard",
    grafana_source    = "grafana-source",
    metrics_endpoint  = "metrics-endpoint",
    tracing           = "tracing",
  }
}

output "app_names" {
  value = merge(
    {
      mimir_coordinator        = module.mimir_coordinator.app_name,
      mimir_overrides_exporter = module.mimir_overrides_exporter.app_name,
      mimir_query_scheduler    = module.mimir_query_scheduler.app_name,
      mimir_flusher            = module.mimir_flusher.app_name,
      mimir_query_frontend     = module.mimir_query_frontend.app_name,
      mimir_querier            = module.mimir_querier.app_name,
      mimir_store_gateway      = module.mimir_store_gateway.app_name,
      mimir_ingester           = module.mimir_ingester.app_name,
      mimir_distributor        = module.mimir_distributor.app_name,
      mimir_ruler              = module.mimir_ruler.app_name,
      mimir_alertmanager       = module.mimir_alertmanager.app_name,
      mimir_compactor          = module.mimir_compactor.app_name,
      s3_integrator            = juju_application.s3_integrator.name,
    }
  )
}

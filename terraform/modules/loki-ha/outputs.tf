output "app_names" {
  value = merge(
    {
      loki_coordinator    = module.loki_coordinator.app_name,
      loki_read           = module.loki_read.app_name,
      loki_write          = module.loki_write.app_name,
      loki_backend        = module.loki_backend.app_name,
      loki_s3_integrator  = juju_application.loki_s3_integrator.name,
    }
  )
}

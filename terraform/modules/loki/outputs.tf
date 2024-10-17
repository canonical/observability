output "app_names" {
  value = merge(
    {
      loki_s3_integrator  = juju_application.s3_integrator.name,
      loki_coordinator    = module.loki_coordinator.app_name,
      loki_backend        = module.loki_backend.app_name,
      loki_read           = module.loki_read.app_name,
      loki_write          = module.loki_write.app_name,
    }
  )
}

output "grafana_dashboards_provider_endpoint" {
  description = "Forwards the built-in Grafana dashboard(s) for monitoring applications."
  value       = "grafana-dashboards-provider"
}

output "grafana_source_endpoint" {
  description = "Name of the endpoint used by apps to create a datasource in Grafana."
  value       = "grafana-source"
}

output "ingress_endpoint" {
  description = "Name of the endpoint used by Loki to provide ingress."
  value       = "ingress"
}

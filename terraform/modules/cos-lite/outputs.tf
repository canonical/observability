output "app_names" {
  value = merge(
    {
      alertmanager = module.alertmanager.app_name,
      catalogue    = module.catalogue.app_name,
      grafana      = module.grafana.app_name,
      loki         = module.loki.app_name,
      prometheus   = module.prometheus.app_name,
      traefik      = module.traefik.app_name,
    }
  )
}

output "grafana" {
  description = "Outputs from the Grafana module"
  value       = module.grafana
}

output "prometheus" {
  description = "Outputs from the prometheus module"
  value       = module.prometheus
}

output "loki" {
  description = "Outputs from the Loki module"
  value       = module.loki
}

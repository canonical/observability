output "app_names" {
  value = merge(
    {
      catalogue = module.catalogue.app_name,
      grafana   = module.grafana.app_name,
      loki      = module.loki.app_names,
      mimir     = module.mimir.app_names,
      traefik   = module.traefik.app_name,
    }
  )
}

output "tempo" {
  description = "Outputs from the Tempo module"
  value       = module.tempo
}

output "mimir" {
  description = "Outputs from the Mimir module"
  value       = module.mimir
}

output "loki" {
  description = "Outputs from the Loki module"
  value       = module.loki
}

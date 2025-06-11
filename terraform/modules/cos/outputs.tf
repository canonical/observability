output "alertmanager" {
  description = "Outputs from the Alertmanager module"
  value       = module.alertmanager
}

output "catalogue" {
  description = "Outputs from the Catalogue module"
  value       = module.catalogue
}

output "grafana" {
  description = "Outputs from the Grafana module"
  value       = module.grafana
}

output "grafana_agent" {
  description = "Outputs from the Grafana Agent module"
  value       = module.grafana_agent
}

output "loki" {
  description = "Outputs from the Loki module"
  value       = module.loki
}

output "mimir" {
  description = "Outputs from the Mimir module"
  value       = module.mimir
}

output "ssc" {
  description = "Outputs from the self-signed certificates module"
  value       = module.ssc
}

output "tempo" {
  description = "Outputs from the Tempo module"
  value       = module.tempo
}

output "traefik" {
  description = "Outputs from the Traefik module"
  value       = module.traefik
}

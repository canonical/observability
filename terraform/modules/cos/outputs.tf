# Integration offers for external systems

output "alertmanager_karma_dashboard_offer_url" {
  description = "Alertmanager Karma Dashboard offer."
  value       = juju_offer.alertmanager-karma-dashboard.url
}

output "grafana_dashboards_offer_url" {
  description = "Grafana Dashboards offer."
  value       = juju_offer.grafana-dashboards.url
}

output "loki_logging_offer_url" {
  description = "Loki Logging offer."
  value       = juju_offer.loki-logging.url
}

output "mimir_receive_remote_write_offer_url" {
  description = "Mimir Receive Remote Write offer."
  value       = juju_offer.mimir-receive-remote-write.url
}

# Observability modules

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

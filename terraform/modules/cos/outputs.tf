# -------------- # Integration offers -------------- #

output "offers" {
  value = {
    alertmanager_karma_dashboard = juju_offer.alertmanager-karma-dashboard
    grafana_dashboards           = juju_offer.grafana-dashboards
    loki_logging                 = juju_offer.loki-logging
    mimir_receive_remote_write   = juju_offer.mimir-receive-remote-write
  }
}

# -------------- # Sub-modules -------------- #

output "components" {
  value = {
    alertmanager  = module.alertmanager
    catalogue     = module.catalogue
    grafana       = module.grafana
    grafana_agent = module.grafana_agent
    loki          = module.loki
    mimir         = module.mimir
    ssc           = module.ssc
    tempo         = module.tempo
    traefik       = module.traefik
  }
}

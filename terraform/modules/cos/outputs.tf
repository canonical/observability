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

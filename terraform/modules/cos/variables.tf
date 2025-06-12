
# the list of kubernetes clouds where this COS module can be deployed.
locals {
  clouds = ["aws", "self-managed"]
}

variable "channel" {
  description = "Channel that the charms are (unless overwritten by external_channels) deployed from"
  type        = string
}

variable "model" {
  description = "Reference to an existing model resource or data source for the model to deploy to"
  type        = string
}

variable "use_tls" {
  description = "Specify whether to use TLS or not for coordinator-worker communication. By default, TLS is enabled through self-signed-certificates"
  type        = bool
  default     = true
}

variable "cloud" {
  description = "Kubernetes cloud or environment where this COS module will be deployed (e.g self-managed, aws)"
  type        = string
  default     = "self-managed"
  validation {
    condition     = contains(local.clouds, var.cloud)
    error_message = "Allowed values are: ${join(", ", local.clouds)}."
  }
}

variable "anti_affinity" {
  description = "Enable anti-affinity constraints across all HA modules (Mimir, Loki, Tempo)"
  type        = bool
  default     = true
}

# -------------- # External channels --------------
# O11y does not own these charms, so we allow users to specify their channels directly.

variable "ssc_channel" {
  description = "Channel that the self-signed certificates charm is deployed from"
  type        = string
  default     = "1/stable"
}

variable "s3_integrator_channel" {
  description = "Channel that the s3-integrator charm is deployed from"
  type        = string
  default     = "2/edge"
}

variable "traefik_channel" {
  description = "Channel that the Traefik charm is deployed from"
  type        = string
  default     = "latest/stable"
}

# -------------- # S3 storage configuration --------------

variable "s3_endpoint" {
  description = "S3 endpoint"
  type        = string
}

variable "s3_access_key" {
  description = "S3 access-key credential"
  type        = string
}

variable "s3_secret_key" {
  description = "S3 secret-key credential"
  type        = string
  sensitive   = true
}

variable "loki_bucket" {
  description = "Loki bucket name"
  type        = string
  sensitive   = true
}

variable "mimir_bucket" {
  description = "Mimir bucket name"
  type        = string
  sensitive   = true
}

variable "tempo_bucket" {
  description = "Tempo bucket name"
  type        = string
  sensitive   = true
}

# -------------- # Charm revisions --------------

variable "alertmanager_revision" {
  description = "Revision number of the Alertmanager charm"
  type        = number
  default     = null
}

variable "catalogue_revision" {
  description = "Revision number of the Catalogue charm"
  type        = number
  default     = null
}

variable "grafana_revision" {
  description = "Revision number of the Grafana charm"
  type        = number
  default     = null
}

variable "grafana_agent_revision" {
  description = "Revision number of the Grafana agent charm"
  type        = number
  default     = null
}

variable "loki_coordinator_revision" {
  description = "Revision number of the Loki coordinator charm"
  type        = number
  default     = null
}

variable "loki_worker_revision" {
  description = "Revision number of the Loki worker charm"
  type        = number
  default     = null
}

variable "mimir_coordinator_revision" {
  description = "Revision number of the Mimir coordinator charm"
  type        = number
  default     = null
}

variable "mimir_worker_revision" {
  description = "Revision number of the Mimir worker charm"
  type        = number
  default     = null
}

variable "ssc_revision" {
  description = "Revision number of the self-signed certificates charm"
  type        = number
  default     = null
}

variable "s3_integrator_revision" {
  description = "Revision number of the s3-integrator charm"
  type        = number
  default     = 157 # FIXME: https://github.com/canonical/observability/issues/342
}

variable "tempo_coordinator_revision" {
  description = "Revision number of the Tempo coordinator charm"
  type        = number
  default     = null
}

variable "tempo_worker_revision" {
  description = "Revision number of the Tempo worker charm"
  type        = number
  default     = null
}

variable "traefik_revision" {
  description = "Revision number of the Traefik charm"
  type        = number
  default     = null
}

# -------------- # Charm unit counts --------------

variable "loki_backend_units" {
  description = "Number of Loki worker units with backend role"
  type        = number
  default     = 3
}

variable "loki_read_units" {
  description = "Number of Loki worker units with read role"
  type        = number
  default     = 3
}

variable "loki_write_units" {
  description = "Number of Loki worker units with write roles"
  type        = number
  default     = 3
}

variable "loki_coordinator_units" {
  description = "Number of Loki coordinator units"
  type        = number
  default     = 3
}

variable "mimir_backend_units" {
  description = "Number of Mimir worker units with backend role"
  type        = number
  default     = 3
}

variable "mimir_read_units" {
  description = "Number of Mimir worker units with read role"
  type        = number
  default     = 3
}

variable "mimir_write_units" {
  description = "Number of Mimir worker units with write role"
  type        = number
  default     = 3
}

variable "mimir_coordinator_units" {
  description = "Number of Mimir coordinator units"
  type        = number
  default     = 3
}

variable "tempo_compactor_units" {
  description = "Number of Tempo worker units with compactor role"
  type        = number
  default     = 3
}

variable "tempo_distributor_units" {
  description = "Number of Tempo worker units with distributor role"
  type        = number
  default     = 3
}

variable "tempo_ingester_units" {
  description = "Number of Tempo worker units with ingester role"
  type        = number
  default     = 3
}

variable "tempo_metrics_generator_units" {
  description = "Number of Tempo worker units with metrics-generator role"
  type        = number
  default     = 3
}

variable "tempo_querier_units" {
  description = "Number of Tempo worker units with querier role"
  type        = number
  default     = 3
}

variable "tempo_query_frontend_units" {
  description = "Number of Tempo worker units with query-frontend role"
  type        = number
  default     = 3
}

variable "tempo_coordinator_units" {
  description = "Number of Tempo coordinator units"
  type        = number
  default     = 3
}

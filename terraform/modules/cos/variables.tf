
# the list of kubernetes clouds where this COS module can be deployed.
locals {
  clouds = ["aws", "self-managed"]
}

variable "channel" {
  description = "Charms channel"
  type        = string
}

variable "model" {
  description = "Reference to an existing model resource or data source for the model to deploy to"
  type        = string
}

variable "charm_revisions" {
  description = "Map of revision numbers for the charms"
  type        = map(number)
  # TODO Try to deploy ommitting some to see if it equates to null
  default = {
    alertmanager      = null
    catalogue         = null
    grafana           = null
    grafana_agent     = null
    loki_coordinator  = null
    loki_worker       = null
    mimir_coordinator = null
    mimir_worker      = null
    tempo_coordinator = null
    tempo_worker      = null
    traefik           = null
  }
}

variable "use_tls" {
  description = "Specify whether to use TLS or not for coordinator-worker communication. By default, TLS is enabled through self-signed-certificates"
  type        = bool
  default     = true
}

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


variable "cloud" {
  description = "Kubernetes cloud or environment where this COS module will be deployed (e.g self-managed, aws)"
  type        = string
  default     = "self-managed"
  validation {
    condition     = contains(local.clouds, var.cloud)
    error_message = "Allowed values are: ${join(", ", local.clouds)}."
  }
}

# O11y does not own this charm, so we allow users to specify the channel directly.
variable "ssc_channel" {
  description = "Channel that the self-signed certificates charm is deployed from"
  type        = string
  default     = "latest/edge"
}

# O11y does not own this charm, so we allow users to specify the channel directly.
variable "traefik_channel" {
  description = "Channel that the traefik charm is deployed from"
  type        = string
  default     = "latest/edge"
}

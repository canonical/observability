
# the list of kubernetes clouds where this COS module can be deployed.
locals {
  clouds = ["aws", "self-managed"]
}
variable "channel" {
  description = "Charms channel"
  type        = string
  default     = "latest/edge"
}

variable "model" {
  description = "Model name"
  type        = string
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

variable "s3_user" {
  description = "User for S3"
  type        = string
}

variable "s3_password" {
  description = "Password for S3"
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

variable "anti_affinity" {
  description = "Enable anti-affinity constraints across all HA modules (Mimir, Loki, Tempo)"
  type        = bool
  default     = true
}

variable "tempo_bucket" {
  description = "Tempo bucket name"
  type        = string
  sensitive   = true
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

# unlike other COS charms, ssc doesn't have a "latest" track for ubuntu@24.04 base.
variable "ssc_channel" {
  description = "self-signed certificates charm channel."
  type        = string
  default     = "latest/edge"
}

# unlike other COS charms, traefik doesn't have COS tracks
variable "traefik_channel" {
  description = "Traefik charm channel."
  type        = string
  default     = "latest/stable"
}

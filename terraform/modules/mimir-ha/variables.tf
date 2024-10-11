variable "channel" {
  description = "Charms channel"
  type        = string
  default     = "latest/edge"
}

variable "model_name" {
  description = "Model name"
  type        = string
}

variable "use_tls" {
  description = "Specify whether to use TLS or not for coordinator-worker communication. By default, TLS is enabled through self-signed-certificates"
  type        = bool
  default     = true
}

variable "create_s3_integrator" {
  type    = bool
  default = true
}

# -------------- # App Names --------------

variable "overrides_exporter_name" {
  description = "Name of the Mimir overrides-exporter app"
  type        = string
  default     = "mimir-overrides-exporter"
}

variable "query_scheduler_name" {
  description = "Name of the Mimir query-scheduler app"
  type        = string
  default     = "mimir-query-scheduler"
}

variable "flusher_name" {
  description = "Name of the Mimir flusher app"
  type        = string
  default     = "mimir-flusher"
}

variable "query_frontend_name" {
  description = "Name of the Mimir query-frontend app"
  type        = string
  default     = "mimir-query-frontend"
}

variable "querier_name" {
  description = "Name of the Mimir querier app"
  type        = string
  default     = "mimir-querier"
}

variable "store_gateway_name" {
  description = "Name of the Mimir store-gateway app"
  type        = string
  default     = "mimir-store-gateway"
}

variable "ingester_name" {
  description = "Name of the Mimir ingester app"
  type        = string
  default     = "mimir-ingester"
}

variable "distributor_name" {
  description = "Name of the Mimir distributor app"
  type        = string
  default     = "mimir-distributor"
}

variable "ruler_name" {
  description = "Name of the Mimir ruler app"
  type        = string
  default     = "mimir-ruler"
}

variable "alertmanager_name" {
  description = "Name of the Mimir alertmanager app"
  type        = string
  default     = "mimir-alertmanager"
}

variable "compactor_name" {
  description = "Name of the Mimir compactor app"
  type        = string
  default     = "mimir-compactor"
}

# -------------- # Units Per App --------------

variable "overrides_exporter_units" {
  description = "Number of Mimir worker units with the overrides-exporter role"
  type        = number
  default     = 1
  validation {
    condition     = var.overrides_exporter_units >= 1
    error_message = "The number of units must be greater than or equal to 1."
  }
}

variable "query_scheduler_units" {
  description = "Number of Mimir worker units with the query-scheduler role"
  type        = number
  default     = 1
  validation {
    condition     = var.query_scheduler_units >= 1
    error_message = "The number of units must be greater than or equal to 1."
  }
}

variable "flusher_units" {
  description = "Number of Mimir worker units with the flusher role"
  type        = number
  default     = 1
  validation {
    condition     = var.flusher_units >= 1
    error_message = "The number of units must be greater than or equal to 1."
  }
}

variable "query_frontend_units" {
  description = "Number of Mimir worker units with the query-frontend role"
  type        = number
  default     = 1
  validation {
    condition     = var.query_frontend_units >= 1
    error_message = "The number of units must be greater than or equal to 1."
  }
}

variable "querier_units" {
  description = "Number of Mimir worker units with the querier role"
  type        = number
  default     = 1
  validation {
    condition     = var.querier_units >= 1
    error_message = "The number of units must be greater than or equal to 1."
  }
}

variable "store_gateway_units" {
  description = "Number of Mimir worker units with the store-gateway role"
  type        = number
  default     = 1
  validation {
    condition     = var.store_gateway_units >= 1
    error_message = "The number of units must be greater than or equal to 1."
  }
}

variable "ingester_units" {
  description = "Number of Mimir worker units with the ingester role"
  type        = number
  default     = 1
  validation {
    condition     = var.ingester_units >= 1
    error_message = "The number of units must be greater than or equal to 1."
  }
}

variable "distributor_units" {
  description = "Number of Mimir worker units with the distributor role"
  type        = number
  default     = 1
  validation {
    condition     = var.distributor_units >= 1
    error_message = "The number of units must be greater than or equal to 1."
  }
}

variable "ruler_units" {
  description = "Number of Mimir worker units with the ruler role"
  type        = number
  default     = 1
  validation {
    condition     = var.ruler_units >= 1
    error_message = "The number of units must be greater than or equal to 1."
  }
}

variable "alertmanager_units" {
  description = "Number of Mimir worker units with the alertmanager role"
  type        = number
  default     = 1
  validation {
    condition     = var.alertmanager_units >= 1
    error_message = "The number of units must be greater than or equal to 1."
  }
}

variable "compactor_units" {
  description = "Number of Mimir worker units with the compactor role"
  type        = number
  default     = 1
  validation {
    condition     = var.compactor_units >= 1
    error_message = "The number of units must be greater than or equal to 1."
  }
}

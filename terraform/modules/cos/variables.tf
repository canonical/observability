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

variable "minio_user" {
  description = "User for MinIO"
  type        = string
}

variable "minio_password" {
  description = "Password for MinIO"
  type        = string
  sensitive   = true
}

variable "loki_backend_units" {
  description = "Number of Loki worker units with backend role"
  type        = number
  default     = 1
}

variable "loki_read_units" {
  description = "Number of Loki worker units with read role"
  type        = number
  default     = 1
}

variable "loki_write_units" {
  description = "Number of Loki worker units with write roles"
  type        = number
  default     = 1
}

variable "mimir_backend_units" {
  description = "Number of Mimir worker units with backend role"
  type        = number
  default     = 1
}

variable "mimir_read_units" {
  description = "Number of Mimir worker units with read role"
  type        = number
  default     = 1
}

variable "mimir_write_units" {
  description = "Number of Mimir worker units with write role"
  type        = number
  default     = 1
}

variable "tempo_compactor_units" {
  description = "Number of Tempo worker units with compactor role"
  type        = number
  default     = 1
}

variable "tempo_distributor_units" {
  description = "Number of Tempo worker units with distributor role"
  type        = number
  default     = 1
}

variable "tempo_ingester_units" {
  description = "Number of Tempo worker units with ingester role"
  type        = number
  default     = 1
}

variable "tempo_metrics_generator_units" {
  description = "Number of Tempo worker units with metrics-generator role"
  type        = number
  default     = 1
}

variable "tempo_querier_units" {
  description = "Number of Tempo worker units with querier role"
  type        = number
  default     = 1
}
variable "tempo_query_frontend_units" {
  description = "Number of Tempo worker units with query-frontend role"
  type        = number
  default     = 1
}
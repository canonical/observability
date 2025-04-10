variable "channel" {
  description = "Charms channel"
  type        = string
  default     = "latest/edge"
}

variable "compactor_units" {
  description = "Number of Tempo worker units with compactor role"
  type        = number
  default     = 1
  validation {
    condition     = var.compactor_units >= 1
    error_message = "The number of units must be greater than or equal to 1."
  }
}

variable "distributor_units" {
  description = "Number of Tempo worker units with distributor role"
  type        = number
  default     = 1
  validation {
    condition     = var.distributor_units >= 1
    error_message = "The number of units must be greater than or equal to 1."
  }
}

variable "ingester_units" {
  description = "Number of Tempo worker units with ingester role"
  type        = number
  default     = 1
  validation {
    condition     = var.ingester_units >= 1
    error_message = "The number of units must be greater than or equal to 1."
  }
}

variable "metrics_generator_units" {
  description = "Number of Tempo worker units with metrics-generator role"
  type        = number
  default     = 1
  validation {
    condition     = var.metrics_generator_units >= 1
    error_message = "The number of units must be greater than or equal to 1."
  }
}


variable "model_name" {
  description = "Model name"
  type        = string
}

variable "querier_units" {
  description = "Number of Tempo worker units with querier role"
  type        = number
  default     = 1
  validation {
    condition     = var.querier_units >= 1
    error_message = "The number of units must be greater than or equal to 1."
  }
}
variable "query_frontend_units" {
  description = "Number of Tempo worker units with query-frontend role"
  type        = number
  default     = 1
  validation {
    condition     = var.query_frontend_units >= 1
    error_message = "The number of units must be greater than or equal to 1."
  }
}

variable "s3_integrator_name" {
  description = "Name of the Loki app with the write role"
  type        = string
  default     = "tempo-s3-integrator"
}

variable "s3_bucket" {
  description = "Bucket name"
  type        = string
  default     = "tempo"
}

variable "s3_user" {
  description = "S3 user"
  type        = string
}

variable "s3_password" {
  description = "S3 password"
  type        = string
}

variable "s3_endpoint" {
  description = "S3 endpoint"
  type        = string
}

variable "remote_ip" {
  description = "The IP address of the remote instance where the Juju client can be used. Defaults to 'localhost' for local execution."
  type        = string
  default     = "localhost"
}

variable "remote_user" {
  description = "The username to use for SSH login to the remote instance where the Juju client can be used. Defaults to the local user running Terraform."
  type        = string
  default     = ""
}

variable "ssh_private_key" {
  description = "The path to the SSH private key used for authentication."
  type        = string
  default     = ""
}

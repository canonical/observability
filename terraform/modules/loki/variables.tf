variable "channel" {
  description = "Charms channel"
  type        = string
  default     = "latest/edge"
}

variable "model_name" {
  description = "Model name"
  type        = string
}

variable "coordinator_revision" {
  description = "Revision number of the coordinator charm"
  type        = number
  default     = null
}

variable "worker_revision" {
  description = "Revision number of the worker charm"
  type        = number
  default     = null
}

variable "s3_bucket" {
  description = "Bucket name"
  type        = string
  default     = "loki"
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

# -------------- # App Names --------------

variable "backend_name" {
  description = "Name of the Loki app with the backend role"
  type        = string
  default     = "loki-backend"
}

variable "read_name" {
  description = "Name of the Loki app with the read role"
  type        = string
  default     = "loki-read"
}

variable "write_name" {
  description = "Name of the Loki app with the write role"
  type        = string
  default     = "loki-write"
}

variable "s3_integrator_name" {
  description = "Name of the Loki app with the write role"
  type        = string
  default     = "loki-s3-integrator"
}
# -------------- # Units Per App --------------

variable "backend_units" {
  description = "Number of Loki worker units with the backend role"
  type        = number
  default     = 1
  validation {
    condition     = var.backend_units >= 1
    error_message = "The number of units must be greater than or equal to 1."
  }
}

variable "read_units" {
  description = "Number of Loki worker units with the read role"
  type        = number
  default     = 1
  validation {
    condition     = var.read_units >= 1
    error_message = "The number of units must be greater than or equal to 1."
  }
}

variable "write_units" {
  description = "Number of Loki worker units with the write role"
  type        = number
  default     = 1
  validation {
    condition     = var.write_units >= 1
    error_message = "The number of units must be greater than or equal to 1."
  }
}

variable "coordinator_units" {
  description = "Number of Loki coordinator units"
  type        = number
  default     = 1
  validation {
    condition     = var.coordinator_units >= 1
    error_message = "The number of units must be greater than or equal to 1."
  }
}

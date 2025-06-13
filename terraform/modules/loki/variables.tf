variable "model" {
  description = "Reference to an existing model resource or data source for the model to deploy to"
  type        = string
}

variable "channel" {
  description = "Channel that the charms are deployed from"
  type        = string
}

variable "s3_integrator_channel" {
  description = "Channel that the s3-integrator charm is deployed from"
  type        = string
  default     = "2/edge"
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

variable "s3_integrator_revision" {
  description = "Revision number of the s3-integrator charm"
  type        = number
  default     = 157 # FIXME: https://github.com/canonical/observability/issues/342
}

variable "s3_bucket" {
  description = "Bucket name"
  type        = string
  default     = "loki"
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

variable "s3_endpoint" {
  description = "S3 endpoint"
  type        = string
}

variable "anti_affinity" {
  description = "Enable anti-affinity constraints."
  type        = bool
  default     = true
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
  description = "Name of the s3-integrator app"
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

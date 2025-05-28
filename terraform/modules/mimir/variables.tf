variable "channel" {
  description = "Charms channel"
  type        = string
  default     = "latest/edge"
}

variable "model_name" {
  description = "Model name"
  type        = string
}

variable "s3_bucket" {
  description = "Bucket name"
  type        = string
  default     = "mimir"
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

variable "read_name" {
  description = "Name of the Mimir read (meta role) app"
  type        = string
  default     = "mimir-read"
}

variable "write_name" {
  description = "Name of the Mimir write (meta role) app"
  type        = string
  default     = "mimir-write"
}

variable "backend_name" {
  description = "Name of the Mimir backend (meta role) app"
  type        = string
  default     = "mimir-backend"
}

variable "s3_integrator_name" {
  description = "Name of the Loki app with the write role"
  type        = string
  default     = "mimir-s3-integrator"
}
# -------------- # Units Per App --------------

variable "read_units" {
  description = "Number of Mimir worker units with the read meta role"
  type        = number
  default     = 1

  validation {
    condition     = var.read_units >= 1
    error_message = "The number of units must be greater than or equal to 1."
  }
}

variable "write_units" {
  description = "Number of Mimir worker units with the write meta role"
  type        = number
  default     = 1

  validation {
    condition     = var.write_units >= 1
    error_message = "The number of units must be greater than or equal to 1."
  }
}

variable "backend_units" {
  description = "Number of Mimir worker units with the backend meta role"
  type        = number
  default     = 1

  validation {
    condition     = var.backend_units >= 1
    error_message = "The number of units must be greater than or equal to 1."
  }
}

variable "coordinator_units" {
  description = "Number of Mimir coordinator units"
  type        = number
  default     = 1

  validation {
    condition     = var.coordinator_units >= 1
    error_message = "The number of units must be greater than or equal to 1."
  }
}

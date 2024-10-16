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

# -------------- # App Names --------------

variable "read_name" {
  description = "Name of the Loki read app"
  type        = string
  default     = "loki-read"
}

variable "write_name" {
  description = "Name of the Loki write app"
  type        = string
  default     = "loki-write"
}

variable "backend_name" {
  description = "Name of the Loki backend app"
  type        = string
  default     = "loki-backend"
}

# -------------- # Units Per App --------------

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

variable "backend_units" {
  description = "Number of Loki worker units with the backend role"
  type        = number
  default     = 1
  validation {
    condition     = var.backend_units >= 1
    error_message = "The number of units must be greater than or equal to 1."
  }
}

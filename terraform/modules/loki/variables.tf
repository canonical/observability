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
  description = "Name of the Loki app with the read role"
  type        = string
  default     = "loki-read"
}

variable "write_name" {
  description = "Name of the Loki app with the write role"
  type        = string
  default     = "loki-write"
}

variable "backend_name" {
  description = "Name of the Loki app with the backend role"
  type        = string
  default     = "loki-backend"
}

# -------------- # Units Per App --------------

variable "read_units" {
  description = "Number of Loki worker units with the read role"
  type        = number
  default     = 1
}

variable "write_units" {
  description = "Number of Loki worker units with the write role"
  type        = number
  default     = 1
}

variable "backend_units" {
  description = "Number of Loki worker units with the backend role"
  type        = number
  default     = 1
}

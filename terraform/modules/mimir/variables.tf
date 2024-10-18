variable "channel" {
  description = "Charms channel"
  type        = string
  default     = "latest/edge"
}

variable "model_name" {
  description = "Model name"
  type        = string
}

# -------------- # App Names --------------

variable "mimir_read_name" {
  description = "Name of the Mimir read app"
  type        = string
  default     = "mimir-read"
}

variable "mimir_write_name" {
  description = "Name of the Mimir write app"
  type        = string
  default     = "mimir-write"
}

variable "mimir_backend_name" {
  description = "Name of the Mimir backend app"
  type        = string
  default     = "mimir-backend"
}


# -------------- # Units Per App --------------

variable "mimir_read_units" {
  description = "Number of Mimir worker units with the read role"
  type        = number
  default     = 1
}

variable "mimir_write_units" {
  description = "Number of Mimir worker units with the write role"
  type        = number
  default     = 1
}

variable "mimir_backend_units" {
  description = "Number of Mimir worker units with the backend role"
  type        = number
  default     = 1
}
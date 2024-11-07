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

variable "meta_read_name" {
  description = "Name of the Mimir read (meta role) app"
  type        = string
  default     = "mimir-read"
}

variable "meta_write_name" {
  description = "Name of the Mimir write (meta role) app"
  type        = string
  default     = "mimir-write"
}




variable "meta_backend_name" {
  description = "Name of the Mimir backend (meta role) app"
  type        = string
  default     = "mimir-backend"
}

# -------------- # Units Per App --------------

variable "meta_read_units" {
  description = "Number of Mimir worker units with the read meta role"
  type        = number
  default     = 1
}

variable "meta_write_units" {
  description = "Number of Mimir worker units with the write meta role"
  type        = number
  default     = 1
}

variable "meta_backend_units" {
  description = "Number of Mimir worker units with the backend meta role"
  type        = number
  default     = 1
}

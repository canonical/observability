variable "channel" {
  description = "Charms channel"
  type        = string
  default     = "latest/edge"
}

variable "model_name" {
  description = "Model name"
  type        = string
}

variable "bucket_name" {
  description = "Model name"
  type        = string
  default     = "loki-bucket"
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
}

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

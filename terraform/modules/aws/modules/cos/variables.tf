variable "model" {
  description = "Model name"
  type        = string
  default     = "cos"
}

variable "loki_bucket" {
  description = "Loki bucket name"
  type        = string
  sensitive   = true
}

variable "tempo_bucket" {
  description = "Tempo bucket name"
  type        = string
  sensitive   = true
}
variable "mimir_bucket" {
  description = "Mimir bucket name"
  type        = string
  sensitive   = true
}

variable "s3_endpoint" {
  description = "S3 endpoint"
  type        = string
}

variable "s3_user" {
  description = "User for S3"
  type        = string
}

variable "s3_password" {
  description = "Password for S3"
  type        = string
  sensitive   = true
}


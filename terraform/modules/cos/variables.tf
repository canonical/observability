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

variable "minio_user" {
  description = "User for MinIO"
  type        = string
}

variable "minio_password" {
  description = "Password for MinIO"
  type        = string
}

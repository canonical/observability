variable "channel" {
  description = "Charms channel"
  type        = string
  default     = "latest/edge"
}

variable "minio_app" {
  description = "Minio user"
  type        = string
  default     = "minio"
}

variable "minio_user" {
  description = "Minio user"
  type        = string
}

variable "minio_password" {
  description = "Minio Password"
  type        = string
}

variable "mc_binary_url" {
  description = "mc binary URL"
  type        = string
  default     = "https://dl.min.io/client/mc/release/linux-amd64/mc"
}
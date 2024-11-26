variable "channel" {
  description = "Charms channel"
  type        = string
  default     = "latest/edge"
}

variable "model_name" {
  description = "Model name"
  type        = string
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

variable "loki" {
  description = "Configuration outputs from the Loki module, including bucket and integrator details."
  type        = any
}

variable "mimir" {
  description = "Configuration outputs from the Mimir module, including bucket and integrator details."
  type        = any
}

variable "tempo" {
  description = "Configuration outputs from the Tempo module, including bucket and integrator details."
  type        = any
}

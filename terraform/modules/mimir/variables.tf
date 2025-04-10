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
}

variable "write_units" {
  description = "Number of Mimir worker units with the write meta role"
  type        = number
  default     = 1
}

variable "backend_units" {
  description = "Number of Mimir worker units with the backend meta role"
  type        = number
  default     = 1
}
variable "remote_ip" {
  description = "The IP address of the remote instance where the Juju client can be used. Defaults to 'localhost' for local execution."
  type        = string
  default     = "localhost"
}

variable "remote_user" {
  description = "The username to use for SSH login to the remote instance where the Juju client can be used. Defaults to the local user running Terraform."
  type        = string
  default     = ""
}

variable "ssh_private_key" {
  description = "The path to the SSH private key used for authentication."
  type        = string
  default     = ""
}

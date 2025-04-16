
# variable "controller_addresses" {
#   description = "Comma-separated addresses of the Juju controller."
#   type        = string
# }

# variable "controller_user" {
#   type = string
# }

# variable "controller_password" {
#   type = string
# }

# variable "controller_ca" {
#   type = string
# }

variable "model" {
  type    = string
  default = "cos"
}

variable "loki_bucket" {
  type = string
}

variable "tempo_bucket" {
  type = string
}
variable "mimir_bucket" {
  type = string
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



# variable "client_host_address" {
#   type = string
# }

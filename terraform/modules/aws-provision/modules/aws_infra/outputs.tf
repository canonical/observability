
# output "management-instance-host" {
#   value = aws_instance.management.public_ip
# }

# output "controller-username" {
#   value = data.external.juju_controller_config.result.juju_username
# }

# output "controller-password" {
#   value     = data.external.juju_controller_config.result.juju_password
#   sensitive = true
# }

# output "controller-ca" {
#   value = data.external.juju_controller_config.result.juju_ca_cert
# }

output "loki-bucket" {
  value = aws_s3_bucket.loki_s3.bucket
}

output "mimir-bucket" {
  value = aws_s3_bucket.mimir_s3.bucket
}
output "tempo-bucket" {
  value = aws_s3_bucket.tempo_s3.bucket
}

output "s3-endpoint" {
  value = "https://s3.${var.region}.amazonaws.com"
}

output "s3-user" {
  value = aws_iam_access_key.s3_access_key.id
}

output "s3-password" {
  value     = aws_iam_access_key.s3_access_key.secret
  sensitive = true
}

output "model" {
  value = "cos"
}

# output "eks-host" {
#   value = aws_eks_cluster.cos_cluster.endpoint
# }

# output "eks-token" {
#   value     = data.aws_eks_cluster_auth.cluster.token
#   sensitive = true
# }

# output "eks-ca-certificate" {
#   value = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
# }



output "loki_bucket" {
  value = aws_s3_bucket.loki_s3.bucket
}

output "mimir_bucket" {
  value = aws_s3_bucket.mimir_s3.bucket
}
output "tempo_bucket" {
  value = aws_s3_bucket.tempo_s3.bucket
}

output "s3_endpoint" {
  value = "https://s3.${var.region}.amazonaws.com"
}

output "s3_user" {
  value = aws_iam_access_key.s3_access_key.id
}

output "s3_password" {
  value     = aws_iam_access_key.s3_access_key.secret
  sensitive = true
}

output "cos_model" {
  value = var.cos_model_name
}



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

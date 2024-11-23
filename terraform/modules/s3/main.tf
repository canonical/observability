resource "juju_application" "minio" {
  # Coordinator requires s3
  name  = var.minio_app
  model = var.model_name
  trust = true

  charm {
    name    = var.minio_app
    channel = var.channel
  }
  units = 1

  config = {
    access-key = var.minio_user
    secret-key = var.minio_password
  }
}

resource "null_resource" "s3fix" {
  triggers = {
    model_name = var.model_name
    minio_app  = var.minio_app
  }
  provisioner "local-exec" {
    command = <<-EOT
      bash "${path.module}/scripts/s3fix.sh" \
        --model-name ${var.model_name} \
        --minio-app ${var.minio_app} \
        --mc-binary-url ${var.mc_binary_url} \
        --minio-url "http://${var.minio_app}-0.${var.minio_app}-endpoints.${var.model_name}.svc.cluster.local:9000" \
        --minio-user ${var.minio_user} \
        --minio-password ${var.minio_password} \
        --loki-bucket ${var.loki.bucket_name} \
        --mimir-bucket ${var.mimir.bucket_name} \
        --tempo-bucket ${var.tempo.bucket_name} \
        --loki-integrator ${var.loki.s3_integrator_name} \
        --mimir-integrator ${var.mimir.s3_integrator_name} \
        --tempo-integrator ${var.tempo.s3_integrator_name}
    EOT
  }

  depends_on = [var.mimir, var.loki, var.tempo]
}
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
      bash ./scripts/s3fix.sh \
        --model-name ${var.model_name} \
        --minio-app ${var.minio_app} \
        --mc-binary-url ${var.mc_binary_url} \
        --minio-url "http://${var.minio_app}-0.${var.minio_app}-endpoints.${var.model_name}.svc.cluster.local:9000" \
        --minio-user ${var.minio_user} \
        --minio-password ${var.minio_password} \
        --loki-bucket ${module.loki.bucket_name} \
        --mimir-bucket ${module.mimir.bucket_name} \
        --tempo-bucket ${module.tempo.bucket_name} \
        --loki-integrator ${module.loki.s3_integrator_name} \
        --mimir-integrator ${module.mimir.s3_integrator_name} \
        --tempo-integrator ${module.tempo.s3_integrator_name}
    EOT
  }

  depends_on = [module.mimir, module.loki, module.tempo]
}
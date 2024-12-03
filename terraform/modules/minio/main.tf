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

resource "null_resource" "s3management" {
  triggers = {
    # model_name = var.model_name
    always_run = timestamp()
  }
  provisioner "local-exec" {
    environment = {
      MINIO_USER     = var.minio_user
      MINIO_PASSWORD = var.minio_password
    }
    command = <<-EOT
      bash "${path.module}/scripts/s3management.sh" \
        --model-name ${var.model_name} \
        --minio-app ${var.minio_app} \
        --mc-binary-url ${var.mc_binary_url} \
        --minio-url "http://${var.minio_app}-0.${var.minio_app}-endpoints.${var.model_name}.svc.cluster.local:9000" \
        --loki-bucket ${var.loki.bucket_name} \
        --mimir-bucket ${var.mimir.bucket_name} \
        --tempo-bucket ${var.tempo.bucket_name} \
        --loki-integrator ${var.loki.s3_integrator_name} \
        --mimir-integrator ${var.mimir.s3_integrator_name} \
        --tempo-integrator ${var.tempo.s3_integrator_name}
    EOT
  }
}
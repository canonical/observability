resource "null_resource" "s3fix" {

  provisioner "local-exec" {
    # There's currently no way to wait for the charm to be idle, hence the sleep
    # https://github.com/juju/terraform-provider-juju/issues/202
    command = <<-EOT
      sleep 600;
      MINIO_URL="http://${var.minio_app}-0.${var.minio_app}-endpoints.${var.model_name}.svc.cluster.local:9000"

      juju ssh -m ${var.model_name} ${var.minio_app}/leader curl ${var.mc_binary_url} --create-dirs -o '/root/minio/mc';
      juju ssh -m ${var.model_name} ${var.minio_app}/leader chmod +x '/root/minio/mc';
      juju ssh -m ${var.model_name} ${var.minio_app}/leader /root/minio/mc alias set local $MINIO_URL ${var.minio_user} ${var.minio_password};
      echo "mc downloaded"

      juju ssh -m ${var.model_name} ${var.minio_app}/leader /root/minio/mc mb local/${module.mimir.bucket_name};
      echo "Bucket: ${module.mimir.bucket_name} created"

      juju ssh -m ${var.model_name} ${var.minio_app}/leader /root/minio/mc mb local/${module.loki.bucket_name};
      echo "Bucket: ${module.loki.bucket_name} created"

      juju ssh -m ${var.model_name} ${var.minio_app}/leader /root/minio/mc mb local/${module.tempo.bucket_name};
      echo "Bucket: ${module.tempo.bucket_name} created"

      juju config ${module.loki.s3_integrator_name} endpoint=$MINIO_URL bucket="${module.loki.bucket_name}";
      echo "${module.loki.s3_integrator_name} configured"

      juju config ${module.mimir.s3_integrator_name} endpoint=$MINIO_URL bucket="${module.mimir.bucket_name}";
      echo "${module.mimir.s3_integrator_name} configured"

      juju config ${module.tempo.s3_integrator_name} endpoint=$MINIO_URL bucket="${module.tempo.bucket_name}";
      echo "${module.tempo.s3_integrator_name} configured"

      juju run -m ${var.model_name} ${module.loki.s3_integrator_name}/leader sync-s3-credentials access-key=${var.minio_user} secret-key=${var.minio_password};
      echo "${module.loki.s3_integrator_name} credential synced"

      juju run -m ${var.model_name} ${module.mimir.s3_integrator_name}/leader sync-s3-credentials access-key=${var.minio_user} secret-key=${var.minio_password};
      echo "${module.mimir.s3_integrator_name} credential synced"

      juju run -m ${var.model_name} ${module.tempo.s3_integrator_name}/leader sync-s3-credentials access-key=${var.minio_user} secret-key=${var.minio_password};
      echo "${module.tempo.s3_integrator_name} credential synced"

      sleep 30;
    EOT
  }
}
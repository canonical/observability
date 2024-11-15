resource "null_resource" "s3fix" {

  provisioner "local-exec" {
    # There's currently no way to wait for the charm to be idle, hence the sleep
    # https://github.com/juju/terraform-provider-juju/issues/202
    command = <<-EOT
      sleep 1200;

      juju ssh -m ${var.model_name} ${var.minio_app}/leader curl https://dl.min.io/client/mc/release/linux-amd64/mc --create-dirs -o '/root/minio/mc';
      juju ssh -m ${var.model_name} ${var.minio_app}/leader chmod +x '/root/minio/mc';
      juju ssh -m ${var.model_name} ${var.minio_app}/leader /root/minio/mc alias set local http://${var.minio_app}-0.${var.minio_app}-endpoints.${var.model_name}.svc.cluster.local:9000 ${var.minio_user} ${var.minio_password};
      juju ssh -m ${var.model_name} ${var.minio_app}/leader /root/minio/mc mb local/${module.mimir.bucket_name};
      juju ssh -m ${var.model_name} ${var.minio_app}/leader /root/minio/mc mb local/${module.loki.bucket_name};
      juju ssh -m ${var.model_name} ${var.minio_app}/leader /root/minio/mc mb local/${module.tempo.bucket_name};

      juju config ${module.loki.s3_integrator_name} endpoint="http://${var.minio_app}-0.${var.minio_app}-endpoints.${var.model_name}.svc.cluster.local:9000" bucket="${module.loki.bucket_name}";
      juju config ${module.mimir.s3_integrator_name} endpoint="http://${var.minio_app}-0.${var.minio_app}-endpoints.${var.model_name}.svc.cluster.local:9000" bucket="${module.mimir.bucket_name}";
      juju config ${module.tempo.s3_integrator_name} endpoint="http://${var.minio_app}-0.${var.minio_app}-endpoints.${var.model_name}.svc.cluster.local:9000" bucket="${module.tempo.bucket_name}";

      juju run -m ${var.model_name} ${module.loki.s3_integrator_name}/leader  sync-s3-credentials access-key=${var.minio_user} secret-key=${var.minio_password};
      juju run -m ${var.model_name} ${module.mimir.s3_integrator_name}/leader sync-s3-credentials access-key=${var.minio_user} secret-key=${var.minio_password};
      juju run -m ${var.model_name} ${module.tempo.s3_integrator_name}/leader sync-s3-credentials access-key=${var.minio_user} secret-key=${var.minio_password};

      sleep 30;
    EOT
  }
}
Terraform module for COS HA solution

This is a Terraform module facilitating the deployment of COS HA solution, using the [Terraform juju provider](https://github.com/juju/terraform-provider-juju/). For more information, refer to the provider [documentation](https://registry.terraform.io/providers/juju/juju/latest/docs).

The HA solution consists of the following Terraform modules:
- [grafana-k8s](https://github.com/canonical/grafana-k8s-operator): Visualization, monitoring,and dashboards.
- [mimir](https://github.com/canonical/observability/tree/main/terraform/modules/mimir): Storage, metrics, and scalability.
- [s3-integrator](https://github.com/canonical/s3-integrator): facade for S3 storage configurations.
- [self-signed-certificates](https://github.com/canonical/self-signed-certificates-operator): certificates operator to secure traffic with TLS.

This Terraform module deploys COS with Mimir and Loki in their microservices modes, and grafana, prometheus, and loki in monolithic mode.

> [!NOTE]
> `s3-integrator` itself doesn't act as an S3 object storage system. For the HA solution to be functional, `s3-integrator` needs to point to an S3-like storage. See [this guide](https://discourse.charmhub.io/t/cos-lite-docs-set-up-minio/15211) to learn how to connect to an S3-like storage for traces.

## Requirements
This module requires a `juju` model to be available. Refer to the [usage section](#usage) below for more details.

## API

### Inputs
The module offers the following configurable inputs:

| Name | Type | Description | Required |
| - | - | - | - |
| `channel` | string | Channel that the charms are deployed from | latest/edge |
| `model_name` | string | Name of the model that the charm is deployed on |  |
| `use_tls` | bool | Specify whether to use TLS or not for coordinator-worker communication |
| `minio_user` | string | User for MinIO |
| `minio_password` | string | Password for MinIO |
| `loki_backend_units` | number | Number of Loki worker units with backend role |
| `loki_backend_units` | number | Number of Loki worker units with backend role |
| `loki_read_units` | number | Number of Loki worker units with read role |
| `loki_write_units` | number | Number of Loki worker units with write role |
| `mimir_backend_units` | number | Number of Mimir worker units with backend role |
| `mimir_read_units` | number | Number of Mimir worker units with read role |
| `mimir_write_units` | number | Number of Mimir worker units with write role |
| `tempo_compactor_units` | number | Number of Tempo worker units with compactor role |
| `tempo_distributor_units` | number | Number of Tempo worker units with distributor role |
| `tempo_ingester_units` | number | Number of Tempo worker units with ingester role |
| `tempo_metrics_generator_units` | number | Number of Tempo worker units with metrics_generator role |
| `tempo_querier_units` | number | Number of Tempo worker units with querier role |
| `tempo_query_frontend_units` | number | Number of Tempo worker units with query_frontend role |



### Outputs
Upon application, the module exports the following outputs:

| Name | Description |
| - | - |
| `app_name`|  Application name |
| `provides`| Map of `provides` endpoints |
| `requires`|  Map of `requires` endpoints |

## Usage


### Basic usage

Users should ensure that Terraform is aware of the `juju_model` dependency of the charm module.

To deploy this module with its needed dependency, you can run `terraform apply -var="model_name=<MODEL_NAME>" -auto-approve`. This would deploy all COS HA solution modules in the same model.

### High Availability

By default, this Terraform module will deploy each worker with `1` unit. If you want to scale each Loki, Mimir or Tempo worker unit please check the variables available for that purpose in `variables.tf`. For instance to deploy 3 units of each Loki worker, you can run:

```shell
terraform apply -var='minio_password=Password' -var='minio_user=User' -var='model_name=test'\
-var='loki_backend_units=3' -var='loki_read_units=3' -var='loki_write_units=3'
```


### Sample deployment

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    juju = {
      source  = "juju/juju"
    }
  }
}

module "cos" {
  source     = "git::https://github.com/canonical/observability//terraform/modules/cos"
  model_name = var.model_name
}

# Assumes that model already exists
variable "model_name" {
  type    = string
}


resource "juju_application" "minio" {
  name = "minio"
  # Coordinator requires s3
  model = var.model_name
  trust = true

  charm {
	name	= "minio"
	channel = "latest/edge"
  }
  units = 1

  config = {
	access-key = "user"
	secret-key = "password"
  }
}


resource "null_resource" "s3management" {

  provisioner "local-exec" {
    # There's currently no way to wait for the charm to be idle, hence the sleep
    # https://github.com/juju/terraform-provider-juju/issues/202
    command = <<-EOT
      sleep 600;

      juju ssh -m cos minio/leader curl https://dl.min.io/client/mc/release/linux-amd64/mc --create-dirs -o '/root/minio/mc';
      juju ssh -m cos minio/leader chmod +x '/root/minio/mc';
      juju ssh -m cos minio/leader /root/minio/mc alias set local http://minio-0.minio-endpoints.cos.svc.cluster.local:9000 user password;
      juju ssh -m cos minio/leader /root/minio/mc mb local/mimir;
      juju ssh -m cos minio/leader /root/minio/mc mb local/loki;
      juju ssh -m cos minio/leader /root/minio/mc mb local/tempo;

      juju config loki-s3-bucket endpoint="http://minio-0.minio-endpoints.cos.svc.cluster.local:9000" bucket="loki";
      juju config mimir-s3-bucket endpoint="http://minio-0.minio-endpoints.cos.svc.cluster.local:9000" bucket="mimir";
      juju config tempo-s3-bucket endpoint="http://minio-0.minio-endpoints.cos.svc.cluster.local:9000" bucket="tempo";

      juju run -m cos loki-s3-bucket/leader sync-s3-credentials access-key=user secret-key=password;
      juju run -m cos mimir-s3-bucket/leader sync-s3-credentials access-key=user secret-key=password;
      juju run -m cos tempo-s3-bucket/leader sync-s3-credentials access-key=user secret-key=password;

      sleep 30;
    EOT
  }
}
```

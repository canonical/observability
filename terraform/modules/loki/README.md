Terraform module for Loki HA solution

This is a Terraform module facilitating the deployment of Loki HA solution, using the [Terraform juju provider](https://github.com/juju/terraform-provider-juju/). For more information, refer to the provider [documentation](https://registry.terraform.io/providers/juju/juju/latest/docs). 

The HA solution consists of the following Terraform modules:
- [loki-coordinator-k8s](https://github.com/canonical/loki-coordinator-k8s-operator): ingress, cluster coordination, single integration facade.
- [loki-worker-k8s](https://github.com/canonical/loki-worker-k8s-operator): run one or more Loki application components.
- [s3-integrator](https://github.com/canonical/s3-integrator): facade for S3 storage configurations.
- [self-signed-certificates](https://github.com/canonical/self-signed-certificates-operator): certificates operator to secure traffic with TLS.

This Terraform module deploys Loki in its [microservices mode](https://grafana.com/docs/enterprise-logs/latest/get-started/deployment-modes/#microservices-mode), which runs each one of the required roles in distinct processes.


> [!NOTE]  
> `s3-integrator` itself doesn't act as an S3 object storage system. For the HA solution to be functional, `s3-integrator` needs to point to an S3-like storage. See [this guide](https://discourse.charmhub.io/t/cos-lite-docs-set-up-minio/15211) to learn how to connect to an S3-like storage for traces.

## Requirements
This module requires a `juju` model to be available. Refer to the [usage section](#usage) below for more details.

## API

### Inputs
The module offers the following configurable inputs:

| Name | Type | Description | Required |
| - | - | - | - |
| `backend_units`| number | Number of Loki worker units with the backend role | 1 |
| `channel`| string | Channel that the charms are deployed from | latest/edge |
| `model_name`| string | Name of the model that the charm is deployed on |  |
| `read_units`| number | Number of Loki worker units with the read role | 1 |
| `use_tls`| bool | Specify whether to use TLS or not for coordinator-worker communication. By default, TLS is enabled through self-signed-certificates | true |
| `write_units`| number | Number of Loki worker units with the write role | 1 |

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

To deploy this module with its needed dependency, you can run `terraform apply -var="model_name=<MODEL_NAME>" -auto-approve`. This would deploy all Loki HA solution modules in the same model.

### Disable TLS

By default, this Terraform module deploys `self-signed-certificates` to secure traffic between the Loki coordinator and worker through TLS. To opt-out and choose to disable TLS, you can configure the variable `use_tls` and run `terraform apply -var="model_name=<MODEL_NAME>" -var="use_tls=false" -auto-approve`

### High Availability 

By default, this Terraform module will deploy each Loki worker with `1` unit. To configure the module to run `x` units of any worker role, you can run `terraform apply -var="model_name=<MODEL_NAME>" -var="<ROLE>_units=<x>" -auto-approve`.
See [Loki worker roles](https://discourse.charmhub.io/t/loki-worker-roles/15484) for the recommended scale for each role.

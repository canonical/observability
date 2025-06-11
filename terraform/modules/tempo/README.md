# Terraform module for Tempo solution

This is a Terraform module facilitating the deployment of Tempo solution, using the [Terraform juju provider](https://github.com/juju/terraform-provider-juju/). For more information, refer to the provider [documentation](https://registry.terraform.io/providers/juju/juju/latest/docs).

The solution consists of the following Terraform modules:
- [tempo-coordinator-k8s](https://github.com/canonical/tempo-coordinator-k8s-operator): ingress, cluster coordination, single integration facade.
- [tempo-worker-k8s](https://github.com/canonical/tempo-worker-k8s-operator): run one or more tempo application components.
- [s3-integrator](https://github.com/canonical/s3-integrator): facade for S3 storage configurations.
- [self-signed-certificates](https://github.com/canonical/self-signed-certificates-operator): certificates operator to secure traffic with TLS.

This Terraform module deploys Tempo in its [microservices mode](https://grafana.com/docs/tempo/latest/setup/deployment/#microservices-mode), which runs each one of the required roles in distinct processes. [See](https://discourse.charmhub.io/t/topic/15484) to understand more about Tempo roles.


> [!NOTE]
> `s3-integrator` itself doesn't act as an S3 object storage system. For the solution to be functional, `s3-integrator` needs to point to an S3-like storage. See [this guide](https://discourse.charmhub.io/t/cos-lite-docs-set-up-minio/15211) to learn how to connect to an S3-like storage for traces.

## Requirements
This module requires a `juju` model to be available. Refer to the [usage section](#usage) below for more details.

## API

### Inputs
The module offers the following configurable inputs:

| Name | Type | Description | Default |
| - | - | - | - |
| `channel`| string | Channel that the charms are deployed from |  |
| `compactor_units`| number | Number of Tempo worker units with compactor role | 1 |
| `distributor_units`| number | Number of Tempo worker units with distributor role | 1 |
| `ingester_units`| number | Number of Tempo worker units with ingester role | 1 |
| `metrics_generator_units`| number | Number of Tempo worker units with metrics-generator role | 1 |
| `model`| string | Name of the model that the charm is deployed on |  |
| `querier_units`| number | Number of Tempo worker units with querier role | 1 |
| `query_frontend_units`| number | Number of Tempo worker units with query-frontend role | 1 |
| `coordinator_units`| number | Number of Tempo coordinator units | 1 |
| `s3_integrator_name` | string | Name of the s3-integrator app | 1 |
| `s3_bucket` | string | Name of the bucke in which Tempo stores traces | 1 |
| `s3_access_key` | string | Access key credential to connect to the S3 provider | 1 |
| `s3_secret_key` | string | Secret key credential to connect to the S3 provider | 1 |
| `s3_endpoint` | string | Endpoint of the S3 provider | 1 |


### Outputs
Upon application, the module exports the following outputs:

| Name | Type | Description |
| - | - | - |
| `app_names`| map(string) | Names of the deployed applications |
| `endpoints`| map(string) | Map of all `provides` and `requires` endpoints |

## Usage


### Basic usage

Users should ensure that Terraform is aware of the `juju_model` dependency of the charm module.

To deploy this module with its needed dependency, you can run `terraform apply -var="model_name=<MODEL_NAME>" -auto-approve`. This would deploy all Tempo components in the same model.

### Microservice deployment

By default, this Terraform module will deploy each Tempo worker with `1` unit. To configure the module to run `x` units of any worker role, you can run `terraform apply -var="model_name=<MODEL_NAME>" -var="<ROLE>_units=<x>" -auto-approve`.
See [Tempo worker roles](https://discourse.charmhub.io/t/tempo-worker-roles/15484) for the recommended scale for each role.

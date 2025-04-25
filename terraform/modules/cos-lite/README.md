Terraform module for COS solution

This is a Terraform module facilitating the deployment of COS solution, using the [Terraform juju provider](https://github.com/juju/terraform-provider-juju/). For more information, refer to the provider [documentation](https://registry.terraform.io/providers/juju/juju/latest/docs).

The COS Lite solution consists of the following Terraform modules:
- [grafana-k8s](https://github.com/canonical/grafana-k8s-operator): Visualization, monitoring, and dashboards.
- [alertmanager-k8s](https://github.com/canonical/alertmanager-k8s-operator): Handles alerts sent by clients applications.
- [prometheus-k8s](https://github.com/canonical/prometheus-k8s-operator/tree/main/terraform/): Backend for metrics
- [loki-k8s](https://github.com/canonical/loki-k8s-operator/tree/main/terraform): Backend for logs
- [self-signed-certificates](https://github.com/canonical/self-signed-certificates-operator): certificates operator to secure traffic with TLS.

## Requirements

This module requires a `juju` model to be available. Refer to the [usage section](#usage) below for more details.

## API

### Inputs

The module offers the following configurable inputs:

| Name         | Type   | Description                                                            | Required    |
|--------------|--------|------------------------------------------------------------------------|-------------|
| `channel`    | string | Channel that the charms are deployed from                              | latest/edge |
| `model_name` | string | Name of the model that the charm is deployed on                        |             |
| `use_tls`    | bool   | Specify whether to use TLS or not for coordinator-worker communication |             |

### Outputs

Upon application, the module exports the following outputs:

| Name       | Description                 |
|------------|-----------------------------|
| `app_name` | Application name            |
| `provides` | Map of `provides` endpoints |
| `requires` | Map of `requires` endpoints |

## Usage


### Basic usage

Users should ensure that Terraform is aware of the `juju_model` dependency of the charm module.

To deploy this module with its needed dependency, you can run `terraform apply -var="model_name=<MODEL_NAME>" -auto-approve`. This would deploy all COS HA solution modules in the same model.


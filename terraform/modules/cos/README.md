# Terraform module for COS solution

This is a Terraform module facilitating the deployment of COS solution, using the [Terraform juju provider](https://github.com/juju/terraform-provider-juju/). For more information, refer to the provider [documentation](https://registry.terraform.io/providers/juju/juju/latest/docs).

The HA solution consists of the following Terraform modules:
- [alertmanager-k8s](https://github.com/canonical/alertmanager-k8s-operator/tree/main/terraform): Handles alerts sent by clients applications.
- [grafana-k8s](https://github.com/canonical/grafana-k8s-operator/tree/main/terraform): Visualization, monitoring, and dashboards.
- [grafana-agent-k8s](https://github.com/canonical/grafana-agent-k8s-operator/tree/main/terraform): Aggregate and send telemetry data.
- [loki](https://github.com/canonical/observability/tree/main/terraform/modules/loki): Backend for logs.
- [mimir](https://github.com/canonical/observability/tree/main/terraform/modules/mimir): Backend for metrics.
- [tempo](https://github.com/canonical/observability/tree/main/terraform/modules/tempo): Backend for traces.
- [s3-integrator](https://github.com/canonical/s3-integrator): facade for S3 storage configurations.
- [self-signed-certificates](https://github.com/canonical/self-signed-certificates-operator/tree/main/terraform): certificates operator to secure traffic with TLS.
- [traefik](https://github.com/canonical/traefik-k8s-operator/tree/main/terraform): ingress.

This Terraform module deploys COS with Mimir, Tempo and Loki in their microservices modes, and other charms in monolithic mode.

> [!NOTE]
> `s3-integrator` itself doesn't act as an S3 object storage system. For the HA solution to be functional, `s3-integrator` needs to point to an S3-like storage. See [this guide](https://discourse.charmhub.io/t/cos-lite-docs-set-up-minio/15211) to learn how to connect to an S3-like storage for traces.

## Requirements
This module requires a `juju` model to be available. Refer to the [usage section](#usage) below for more details.

## API

### Inputs
The module offers the following configurable inputs:

| Name | Type | Description                                                    | Default |
| - | - |----------------------------------------------------------------| - |
| `channel` | string | Channel that all the charms (unless overwritten) are deployed from |
| `ssc_channel` | string | Channel that the self-signed certificates charm is deployed from | latest/edge |
| `traefik_channel` | string | Channel that the traefik charm is deployed from | latest/edge |
| `model` | string | Reference to an existing model resource or data source for the model to deploy to |
| `use_tls` | bool | Specify whether to use TLS or not for in-cluster communication |
| `cloud` | string | Kubernetes cloud or environment where this COS module will be deployed | self-managed |
| `loki_coordinator_units` | number | Number of Loki coordinator units |
| `loki_backend_units` | number | Number of Loki worker units with `backend` role |
| `loki_read_units` | number | Number of Loki worker units with `read` role |
| `loki_write_units` | number | Number of Loki worker units with `write` role |
| `mimir_coordinator_units` | number | Number of Mimir coordinator units |
| `mimir_backend_units` | number | Number of Mimir worker units with `backend` role |
| `mimir_read_units` | number | Number of Mimir worker units with `read` role |
| `mimir_write_units` | number | Number of Mimir worker units with `write` role |
| `tempo_coordinator_units` | number | Number of Tempo coordinator units |
| `tempo_compactor_units` | number | Number of Tempo worker units with `compactor` role |
| `tempo_distributor_units` | number | Number of Tempo worker units with `distributor` role |
| `tempo_ingester_units` | number | Number of Tempo worker units with `ingester` role |
| `tempo_metrics_generator_units` | number | Number of Tempo worker units with `metrics_generator` role |
| `tempo_querier_units` | number | Number of Tempo worker units with `querier` role |
| `tempo_query_frontend_units` | number | Number of Tempo worker units with `query_frontend` role |
| `s3_access_key` | string | Access key credential to connect to the S3 provider | 1 |
| `s3_secret_key` | string | Secret key credential to connect to the S3 provider | 1 |
| `s3_endpoint` | string | S3 provider endpoint                                           | 1 |
| `loki_bucket` | string | Name of the bucket in which Loki should store its logs         | 1 |
| `mimir_bucket` | string | Name of the bucket in which Mimir should store its metrics     | 1 |
| `tempo_bucket` | string | Name of the bucket in which Tempo should store its traces      | 1 |
| `alertmanager_revision` | number | Revision number of the charm | null |
| `catalogue_revision` | number | Revision number of the charm | null |
| `grafana_revision` | number | Revision number of the charm | null |
| `grafana_agent_revision` | number | Revision number of the charm | null |
| `loki_coordinator_revision` | number | Revision number of the charm | null |
| `loki_worker_revision` | number | Revision number of the charm | null |
| `mimir_coordinator_revision` | number | Revision number of the charm | null |
| `mimir_worker_revision` | number | Revision number of the charm | null |
| `ssc_revision` | number | Revision number of the charm | null |
| `s3_integrator_revision` | number | Revision number of the charm | null |
| `tempo_coordinator_revision` | number | Revision number of the charm | null |
| `tempo_worker_revision` | number | Revision number of the charm | null |
| `traefik_revision` | number | Revision number of the charm | null |

### Outputs
Upon application, the module exports the following outputs:

| Name | Type | Description |
| - | - | - |
| `alertmanager`| module | Alertmanager module |
| `catalogue`| module | Catalogue module |
| `grafana`| module | Grafana module |
| `grafana_agent`| module | Grafana agent module |
| `loki`| module | Loki module |
| `mimir`| module | Mimir module |
| `ssc`| module | Self-signed certificates module |
| `tempo`| module | Tempo module |
| `traefik`| module | Traefik module |


## Usage


### Basic usage

Users should ensure that Terraform is aware of the `juju_model` dependency of the charm module.

To deploy this module with its needed dependency, you can run `terraform apply -var="model=<MODEL_NAME>" -auto-approve`. This would deploy all COS HA solution modules in the same model.

### High Availability

By default, this Terraform module will deploy each worker with `3` unit. If you want to scale each Loki, Mimir or Tempo worker unit please check the variables available for that purpose in `variables.tf`.

### Minimal sample deployment.

In order to deploy COS with just one unit per worker charm create a `main.tf` file with the following content:

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# COS module that deploy the whole Canonical Observability Stack
module "cos" {
    source                        = "git::https://github.com/canonical/observability//terraform/modules/cos"
    model                         = "cos"
    channel                       = "2/edge"
    s3_integrator_channel         = "2/edge"
    ssc_channel                   = "1/edge"
    traefik_channel               = "latest/edge"
    cloud                         = "self-managed"
    use_tls                       = true
    s3_endpoint                   = "http://S3_HOST_IP:8080"
    s3_secret_key                 = "secret-key"
    s3_access_key                 = "access-key"
    loki_bucket                   = "loki"
    mimir_bucket                  = "mimir"
    tempo_bucket                  = "tempo"
    loki_coordinator_units        = 3
    loki_backend_units            = 3
    loki_read_units               = 3
    loki_write_units              = 3
    mimir_coordinator_units       = 3
    mimir_backend_units           = 3
    mimir_read_units              = 3
    mimir_write_units             = 3
    tempo_coordinator_units       = 3
    tempo_compactor_units         = 3
    tempo_distributor_units       = 3
    tempo_ingester_units          = 3
    tempo_metrics_generator_units = 3
    tempo_querier_units           = 3
    tempo_query_frontend_units    = 3
    alertmanager_revision         = null
    catalogue_revision            = null
    grafana_revision              = null
    grafana_agent_revision        = null
    loki_coordinator_revision     = null
    loki_worker_revision          = null
    mimir_coordinator_revision    = null
    mimir_worker_revision         = null
    ssc_revision                  = null
    s3_integrator_revision        = 157 # FIXME: This is a temporary fix until the spec for the s3-integrator is stable.
    tempo_coordinator_revision    = null
    tempo_worker_revision         = null
    traefik_revision              = null
}
```

Then, use terraform to deploy the module:

```shell
terraform init
terraform apply
```

Some minutes after running these two commands, we have a distributed COS deployment!

```shell
$ juju status --relations
Model  Controller  Cloud/Region        Version  SLA          Timestamp
cos    microk8s    microk8s/localhost  3.6.2    unsupported  20:16:42-03:00

App                       Version  Status  Scale  Charm                     Channel      Rev  Address         Exposed  Message
alertmanager              0.27.0   active      1  alertmanager-k8s          latest/edge  156  10.152.183.57   no
catalogue                          active      1  catalogue-k8s             latest/edge   81  10.152.183.88   no
grafana                   9.5.3    active      1  grafana-k8s               latest/edge  141  10.152.183.138  no
grafana-agent             0.40.4   active      1  grafana-agent-k8s         latest/edge  112  10.152.183.37   no       grafana-dashboards-provider: off
loki                               active      3  loki-coordinator-k8s      latest/edge   20  10.152.183.201  no
loki-backend              3.0.0    active      3  loki-worker-k8s           latest/edge   34  10.152.183.112  no       backend ready.
loki-read                 3.0.0    active      3  loki-worker-k8s           latest/edge   34  10.152.183.87   no       read ready.
loki-s3-integrator                 active      1  s3-integrator             latest/edge  139  10.152.183.20   no
loki-write                3.0.0    active      3  loki-worker-k8s           latest/edge   34  10.152.183.167  no       write ready.
mimir                              active      3  mimir-coordinator-k8s     latest/edge   38  10.152.183.207  no
mimir-backend             2.13.0   active      3  mimir-worker-k8s          latest/edge   45  10.152.183.45   no       backend ready.
mimir-read                2.13.0   active      3  mimir-worker-k8s          latest/edge   45  10.152.183.160  no       read ready.
mimir-s3-integrator                active      1  s3-integrator             latest/edge  139  10.152.183.85   no
mimir-write               2.13.0   active      3  mimir-worker-k8s          latest/edge   45  10.152.183.125  no       write ready.
self-signed-certificates           active      1  self-signed-certificates  1/edge       268  10.152.183.34   no
tempo                              active      3  tempo-coordinator-k8s     latest/edge   70  10.152.183.72   no
tempo-compactor           2.7.1    active      3  tempo-worker-k8s          latest/edge   52  10.152.183.99   no       compactor ready.
tempo-distributor         2.7.1    active      3  tempo-worker-k8s          latest/edge   52  10.152.183.162  no       distributor ready.
tempo-ingester            2.7.1    active      3  tempo-worker-k8s          latest/edge   52  10.152.183.195  no       ingester ready.
tempo-metrics-generator   2.7.1    active      3  tempo-worker-k8s          latest/edge   52  10.152.183.122  no       metrics-generator ready.
tempo-querier             2.7.1    active      3  tempo-worker-k8s          latest/edge   52  10.152.183.136  no       querier ready.
tempo-query-frontend      2.7.1    active      3  tempo-worker-k8s          latest/edge   52  10.152.183.105  no       query-frontend ready.
tempo-s3-integrator                active      1  s3-integrator             latest/edge  139  10.152.183.121  no
traefik                   2.11.0   active      1  traefik-k8s               latest/edge  234  10.152.183.110  no       Serving at 192.168.1.244

Unit                         Workload  Agent  Address       Ports  Message
alertmanager/0*              active    idle   10.1.167.134
catalogue/0*                 active    idle   10.1.167.150
grafana-agent/0*             active    idle   10.1.167.149         grafana-dashboards-provider: off
grafana/0*                   active    idle   10.1.167.173
loki-backend/0*              active    idle   10.1.167.148         backend ready.
loki-backend/1               active    idle   10.1.167.171         backend ready.
loki-backend/2               active    idle   10.1.167.188         backend ready.
loki-read/0                  active    idle   10.1.167.153         read ready.
loki-read/1                  active    idle   10.1.167.180         read ready.
loki-read/2*                 active    idle   10.1.167.183         read ready.
loki-s3-integrator/0*        active    idle   10.1.167.169
loki-write/0*                active    idle   10.1.167.144         write ready.
loki-write/1                 active    idle   10.1.167.142         write ready.
loki-write/2                 active    idle   10.1.167.187         write ready.
loki/0*                      active    idle   10.1.167.174
mimir-backend/0*             active    idle   10.1.167.139         backend ready.
mimir-backend/1              active    idle   10.1.167.128         backend ready.
mimir-backend/2              active    idle   10.1.167.177         backend ready.
mimir-read/0*                active    idle   10.1.167.151         read ready.
mimir-read/1                 active    idle   10.1.167.163         read ready.
mimir-read/2                 active    idle   10.1.167.132         read ready.
mimir-s3-integrator/0*       active    idle   10.1.167.137
mimir-write/0*               active    idle   10.1.167.152         write ready.
mimir-write/1                active    idle   10.1.167.167         write ready.
mimir-write/2                active    idle   10.1.167.143         write ready.
mimir/0*                     active    idle   10.1.167.135
self-signed-certificates/0*  active    idle   10.1.167.166
tempo-compactor/0            active    idle   10.1.167.181         compactor ready.
tempo-compactor/1*           active    idle   10.1.167.168         compactor ready.
tempo-compactor/2            active    idle   10.1.167.129         compactor ready.
tempo-distributor/0*         active    idle   10.1.167.157         distributor ready.
tempo-distributor/1          active    idle   10.1.167.131         distributor ready.
tempo-distributor/2          active    idle   10.1.167.186         distributor ready.
tempo-ingester/0*            active    idle   10.1.167.191         ingester ready.
tempo-ingester/1             active    idle   10.1.167.133         ingester ready.
tempo-ingester/2             active    idle   10.1.167.179         ingester ready.
tempo-metrics-generator/0*   active    idle   10.1.167.147         metrics-generator ready.
tempo-metrics-generator/1    active    idle   10.1.167.159         metrics-generator ready.
tempo-metrics-generator/2    active    idle   10.1.167.146         metrics-generator ready.
tempo-querier/0              active    idle   10.1.167.170         querier ready.
tempo-querier/1              active    idle   10.1.167.140         querier ready.
tempo-querier/2*             active    idle   10.1.167.165         querier ready.
tempo-query-frontend/0*      active    idle   10.1.167.162         query-frontend ready.
tempo-query-frontend/1       active    idle   10.1.167.190         query-frontend ready.
tempo-query-frontend/2       active    idle   10.1.167.184         query-frontend ready.
tempo-s3-integrator/0*       active    idle   10.1.167.172
tempo/0*                     active    idle   10.1.167.189
traefik/0*                   active    idle   10.1.167.182         Serving at 192.168.1.244

Integration provider                     Requirer                                 Interface                Type     Message
alertmanager:alerting                    loki:alertmanager                        alertmanager_dispatch    regular
alertmanager:alerting                    mimir:alertmanager                       alertmanager_dispatch    regular
alertmanager:grafana-dashboard           grafana:grafana-dashboard                grafana_dashboard        regular
alertmanager:grafana-source              grafana:grafana-source                   grafana_datasource       regular
alertmanager:replicas                    alertmanager:replicas                    alertmanager_replica     peer
alertmanager:self-metrics-endpoint       grafana-agent:metrics-endpoint           prometheus_scrape        regular
catalogue:catalogue                      alertmanager:catalogue                   catalogue                regular
catalogue:catalogue                      grafana:catalogue                        catalogue                regular
catalogue:catalogue                      mimir:catalogue                          catalogue                regular
catalogue:catalogue                      tempo:catalogue                          catalogue                regular
catalogue:replicas                       catalogue:replicas                       catalogue_replica        peer
grafana-agent:logging-provider           loki:logging-consumer                    loki_push_api            regular
grafana-agent:logging-provider           tempo:logging                            loki_push_api            regular
grafana-agent:peers                      grafana-agent:peers                      grafana_agent_replica    peer
grafana-agent:tracing-provider           grafana:charm-tracing                    tracing                  regular
grafana-agent:tracing-provider           loki:charm-tracing                       tracing                  regular
grafana-agent:tracing-provider           mimir:charm-tracing                      tracing                  regular
grafana:grafana                          grafana:grafana                          grafana_peers            peer
grafana:replicas                         grafana:replicas                         grafana_replicas         peer
loki-s3-integrator:s3-credentials        loki:s3                                  s3                       regular
loki-s3-integrator:s3-integrator-peers   loki-s3-integrator:s3-integrator-peers   s3-integrator-peers      peer
loki:grafana-dashboards-provider         grafana:grafana-dashboard                grafana_dashboard        regular
loki:grafana-source                      grafana:grafana-source                   grafana_datasource       regular
loki:logging                             grafana-agent:logging-consumer           loki_push_api            regular
loki:loki-cluster                        loki-backend:loki-cluster                loki_cluster             regular
loki:loki-cluster                        loki-read:loki-cluster                   loki_cluster             regular
loki:loki-cluster                        loki-write:loki-cluster                  loki_cluster             regular
loki:self-metrics-endpoint               grafana-agent:metrics-endpoint           prometheus_scrape        regular
mimir-s3-integrator:s3-credentials       mimir:s3                                 s3                       regular
mimir-s3-integrator:s3-integrator-peers  mimir-s3-integrator:s3-integrator-peers  s3-integrator-peers      peer
mimir:grafana-dashboards-provider        grafana:grafana-dashboard                grafana_dashboard        regular
mimir:grafana-source                     grafana:grafana-source                   grafana_datasource       regular
mimir:mimir-cluster                      mimir-backend:mimir-cluster              mimir_cluster            regular
mimir:mimir-cluster                      mimir-read:mimir-cluster                 mimir_cluster            regular
mimir:mimir-cluster                      mimir-write:mimir-cluster                mimir_cluster            regular
mimir:receive-remote-write               grafana-agent:send-remote-write          prometheus_remote_write  regular
mimir:receive-remote-write               tempo:send-remote-write                  prometheus_remote_write  regular
mimir:self-metrics-endpoint              grafana-agent:metrics-endpoint           prometheus_scrape        regular
tempo-s3-integrator:s3-credentials       tempo:s3                                 s3                       regular
tempo-s3-integrator:s3-integrator-peers  tempo-s3-integrator:s3-integrator-peers  s3-integrator-peers      peer
tempo:grafana-source                     grafana:grafana-source                   grafana_datasource       regular
tempo:metrics-endpoint                   grafana-agent:metrics-endpoint           prometheus_scrape        regular
tempo:peers                              tempo:peers                              tempo_peers              peer
tempo:tempo-cluster                      tempo-compactor:tempo-cluster            tempo_cluster            regular
tempo:tempo-cluster                      tempo-distributor:tempo-cluster          tempo_cluster            regular
tempo:tempo-cluster                      tempo-ingester:tempo-cluster             tempo_cluster            regular
tempo:tempo-cluster                      tempo-metrics-generator:tempo-cluster    tempo_cluster            regular
tempo:tempo-cluster                      tempo-querier:tempo-cluster              tempo_cluster            regular
tempo:tempo-cluster                      tempo-query-frontend:tempo-cluster       tempo_cluster            regular
tempo:tracing                            grafana-agent:tracing                    tracing                  regular
traefik:ingress                          alertmanager:ingress                     ingress                  regular
traefik:ingress                          catalogue:ingress                        ingress                  regular
traefik:ingress                          loki:ingress                             ingress                  regular
traefik:ingress                          mimir:ingress                            ingress                  regular
traefik:peers                            traefik:peers                            traefik_peers            peer
traefik:traefik-route                    grafana:ingress                          traefik_route            regular
traefik:traefik-route                    tempo:ingress                            traefik_route            regular
```

### Deploy COS on AWS EKS

> **Note:** This deployment assumes that the required AWS infrastructure is already provisioned and that a Juju controller has been bootstrapped.  
> Additionally, a Juju model must be ready in advance.
> 
> See [provision AWS infrastructure](../aws-infra/README.md)

In order to deploy COS on AWS, create a `main.tf` file with the following content.

```hcl
# COS module that deploy the whole Canonical Observability Stack
module "cos" {
  source                        = "git::https://github.com/canonical/observability//terraform/modules/cos"
  model_name                    = var.model_name
  channel                       = var.channel
  s3_endpoint                   = var.s3_endpoint
  s3_access_key                 = var.s3_access_key
  s3_secret_key                 = var.s3_secret_key
  loki_bucket                   = var.loki_bucket
  mimir_bucket                  = var.mimir_bucket
  tempo_bucket                  = var.tempo_bucket
  loki_backend_units            = var.loki_backend_units
  loki_read_units               = var.loki_read_units
  loki_write_units              = var.loki_write_units
  mimir_backend_units           = var.mimir_backend_units
  mimir_read_units              = var.mimir_read_units
  mimir_write_units             = var.mimir_write_units
  tempo_compactor_units         = var.tempo_compactor_units
  tempo_distributor_units       = var.tempo_distributor_units
  tempo_ingester_units          = var.tempo_ingester_units
  tempo_metrics_generator_units = var.tempo_metrics_generator_units
  tempo_querier_units           = var.tempo_querier_units
  tempo_query_frontend_units    = var.tempo_query_frontend_units
  cloud                         = var.cloud
  ssc_channel                   = var.ssc_channel
}

variable "channel" {
  description = "Charms channel"
  type        = string
  default     = "latest/edge"
}

variable "model_name" {
  description = "Model name"
  type        = string
}

variable "use_tls" {
  description = "Specify whether to use TLS or not for coordinator-worker communication. By default, TLS is enabled through self-signed-certificates"
  type        = bool
  default     = true
}

variable "s3_endpoint" {
  description = "S3 endpoint"
  type        = string
}

variable "s3_access_key" {
  description = "S3 access key"
  type        = string
  sensitive   = true
}

variable "s3_secret_key" {
  description = "S3 secret key"
  type        = string
  sensitive   = true
}

variable "loki_bucket" {
  description = "Loki bucket name"
  type        = string
  sensitive   = true
}

variable "mimir_bucket" {
  description = "Mimir bucket name"
  type        = string
  sensitive   = true
}

variable "tempo_bucket" {
  description = "Tempo bucket name"
  type        = string
  sensitive   = true
}

variable "loki_backend_units" {
  description = "Number of Loki worker units with backend role"
  type        = number
  default     = 3
}

variable "loki_read_units" {
  description = "Number of Loki worker units with read role"
  type        = number
  default     = 3
}

variable "loki_write_units" {
  description = "Number of Loki worker units with write roles"
  type        = number
  default     = 3
}

variable "mimir_backend_units" {
  description = "Number of Mimir worker units with backend role"
  type        = number
  default     = 3
}

variable "mimir_read_units" {
  description = "Number of Mimir worker units with read role"
  type        = number
  default     = 3
}

variable "mimir_write_units" {
  description = "Number of Mimir worker units with write role"
  type        = number
  default     = 3
}

variable "tempo_compactor_units" {
  description = "Number of Tempo worker units with compactor role"
  type        = number
  default     = 3
}

variable "tempo_distributor_units" {
  description = "Number of Tempo worker units with distributor role"
  type        = number
  default     = 3
}

variable "tempo_ingester_units" {
  description = "Number of Tempo worker units with ingester role"
  type        = number
  default     = 3
}

variable "tempo_metrics_generator_units" {
  description = "Number of Tempo worker units with metrics-generator role"
  type        = number
  default     = 3
}

variable "tempo_querier_units" {
  description = "Number of Tempo worker units with querier role"
  type        = number
  default     = 3
}
variable "tempo_query_frontend_units" {
  description = "Number of Tempo worker units with query-frontend role"
  type        = number
  default     = 3
}

variable "cloud" {
  description = "Kubernetes cloud or environment where this COS module will be deployed (e.g self-managed, aws)"
  type        = string
  default     = "self-managed"
}

# ssc doesn't have a "latest" track for ubuntu@24.04 base.
variable "ssc_channel" {
  description = "self-signed certificates charm channel."
  type        = string
  default     = "latest/edge"
}

```
Then, create a `aws.tfvars` file with the following content:

```hcl
cloud = "aws"
# If you're deploying on an ubuntu@24.04 base
ssc_channel  = "1/edge"
model        = "<model-name>"
s3_endpoint  = "<s3-endpoint>"
s3_access_key  = "<s3-access-key>"
s3_secret_key  = "<s3-secret-key>"
loki_bucket  = "<loki-bucket>"
mimir_bucket = "<mimir-bucket>"
tempo_bucket = "<tempo-bucket>"
```

Then, use terraform to deploy the module:
```bash
terraform init
terraform apply -var-file=aws.tfvars
```

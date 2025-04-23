# From Zero to COS: End-to-End AWS Provisioning & Deployment

This directory contains Terraform modules for automating the process of bootstrapping a fresh AWS account to a fully running instance of COS deployed on a 3-node EKS cluster.

Using `just` commands, we can:

- Provision all COS-required AWS infrastructure (networking, IAM, EKS, etc.)
- Deploy COS on top of the freshly created infrastructure

---


## Available Commands (via `just`)

- `just init` – Initialize Terraform for AWS infra and COS
- `just apply` – Provision AWS infrastructure, then pipe the necessary outputs to provision COS on top
- `just destroy` – Tear down everything (COS + infra)

## Prerequisites

Make sure you have the following installed:

- [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) >= v1.10.4
- [AWS CLI](https://github.com/aws/aws-cli) >= 2.26.7
- [Juju](https://snapcraft.io/juju) >= 3.0.3
- [Just](https://github.com/casey/just) >= 1.40.0

### AWS Credentials Setup

Before running any commands, ensure your AWS credentials are configured on the host:

You can do this using one of the following methods:

- [Environment variables](https://docs.aws.amazon.com/cli/v1/userguide/cli-configure-envvars.html)
- [Credentials file](https://docs.aws.amazon.com/cli/v1/userguide/cli-configure-files.html)

---


## Usage

To go from zero to COS:

1. Create a [`modules/infra/terraform.tfvars`](modules/infra/terraform.tfvars) with the following required content.
```hcl
region = "<your-aws-region>"
# Add other optional variables below
cos-cloud-name = "<cos-cloud-name>"
cos-controller-name = "<cos-controller-name>"
cos-model-name = "<cos-model-name>"
```
2. `just apply`

---


## Inputs

| Variable Name     | Description             |
|----------|-------------------------|
| region   | AWS region to provision resources in |
| cos-cloud-name   | The name to assign to the Kubernetes cloud when running 'juju add-k8s' |
| cos-controller-name   | The name to assign to the Juju controller that will manage COS |
| cos-model-name   | The name of the Juju model where COS will be deployed |

All `cos` module needed variables are passed automatically from this `aws-infra` module to the `cos` module.

---




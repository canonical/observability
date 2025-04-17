# From Zero to COS: End-to-End AWS Provisioning & Deployment

This directory contains Terraform modules for automating the process of bootstrapping a fresh AWS account to a fully running instance of COS deployed on a 3-node EKS cluster.

Using `just` commands, we can:

- Provision all COS-required AWS infrastructure (networking, IAM, EKS, etc.)
- Deploy COS on top of the freshly created infrastructure

---

## Directory Structure

- **root directory** – Contains a `just` file with commands that wrap around `terraform init`, `terraform apply` and `terraform destroy` for both modules in the correct order.
- **modules/infra** – Provisions all COS-required AWS resources and bootstraps a Juju controller
- **modules/cos** – Deploys COS on the AWS-provisioned infrastructure

---

## Available Commands (via `just`)

- `just init` – Initialize Terraform in both modules
- `just apply` – Provision AWS infrastructure, then pipe the necessary outputs to provision COS on top
- `just destroy` – Tear down everything (COS + infra)

## Prerequisites

Make sure you have the following installed:

- [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
- [AWS CLI](https://github.com/aws/aws-cli)
- [Juju](https://snapcraft.io/juju)
- [Just](https://github.com/casey/just)

### AWS Credentials Setup

Before running any commands, ensure your AWS credentials are configured on the host:

You can do this using one of the following methods:

- [Environment variables](https://docs.aws.amazon.com/cli/v1/userguide/cli-configure-envvars.html)
- [Credentials file](https://docs.aws.amazon.com/cli/v1/userguide/cli-configure-files.html)

---


## Usage

### Option 1: Full Bootstrap (Provision Infra + Deploy COS)

To go from zero to COS:

```
just apply <aws_region>
```

---

### Option 2: Deploy COS only

> **Note:** This option assumes that the required AWS infrastructure already exists and that a Juju controller has been bootstrapped.  
> Additionally, a Juju model must also be created. 

```
cd modules/cos
terraform apply -var="model=<model_name>" -var=...
```

You must manually provide all required inputs. See the table below.

---

## Variables

### When using `just apply` (Full Bootstrap)

| Name     | Description             |
|----------|-------------------------|
| <aws_region>   | AWS region to provision resources in |

All other needed variables are passed automatically from the `infra` module to the `cos` module.

---

### When running `terraform apply` manually inside `modules/cos`


| Variable Name      | Description                                |
|--------------------|--------------------------------------------|
| model             | (Optional) The model name where COS will be deployed                     |
| loki_bucket         | Loki bucket name          |
| tempo_bucket           | Tempo bucket name            |
| mimir_bucket             | Mimir bucket name           |
| s3_endpoint   | S3 endpoint |
| s3_user   | S3 access key ID |
| s3_password   | S3 secret key |

---




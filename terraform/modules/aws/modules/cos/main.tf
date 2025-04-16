# bootstrap COS
provider "juju" {}


module "cos" {
  # FIXME: use the remote module
  source       = "../../../cos"
  model_name   = var.model
  use_tls      = true
  loki_bucket  = var.loki_bucket
  mimir_bucket = var.mimir_bucket
  tempo_bucket = var.tempo_bucket
  s3_endpoint  = var.s3_endpoint
  s3_user      = var.s3_user
  s3_password  = var.s3_password
  cloud        = "aws"
  channel      = "latest/edge"
  ssc_channel  = "1/edge"

}


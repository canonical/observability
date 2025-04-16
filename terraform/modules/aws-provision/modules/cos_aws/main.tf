# bootstrap COS
provider "juju" {
  #   controller_addresses = "${kubernetes_service.controller_public_nlb.status[0].load_balancer[0].ingress[0].hostname}:17070"
  #   username             = data.external.juju_controller_config.result.juju_username
  #   password             = data.external.juju_controller_config.result.juju_password
  #   ca_certificate       = data.external.juju_controller_config.result.juju_ca_cert
  # controller_addresses = var.controller_addresses
  # username             = var.controller_user
  # password             = var.controller_password
  # ca_certificate       = var.controller_ca
}

# resource "juju_model" "cos_model" {
#   #   depends_on = [kubernetes_service.controller_public_nlb, data.external.juju_controller_config]
#   name = var.model
#   cloud {
#     name   = "cos-cloud"
#     region = var.aws_region
#   }
# }

module "cos" {
  #   depends_on   = [aws_s3_bucket.loki_s3, aws_s3_bucket.mimir_s3, aws_s3_bucket.tempo_s3, juju_model.cos_model]
  # FIXME: use the remote module
  source     = "../../../cos"
  model_name = var.model
  use_tls    = true
  # loki_bucket  = aws_s3_bucket.loki_s3.bucket
  # mimir_bucket = aws_s3_bucket.mimir_s3.bucket
  # tempo_bucket = aws_s3_bucket.tempo_s3.bucket
  # s3_endpoint  = "https://s3.${var.region}.amazonaws.com"
  # s3_user      = aws_iam_access_key.s3_access_key.id
  # s3_password  = aws_iam_access_key.s3_access_key.secret
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


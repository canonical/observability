# hacky way to create a publicly accessible Juju controller
# Juju creates an internal controller not accessible by the Juju provider terraform provider
provider "kubernetes" {
  host                   = var.host
  token                  = var.token
  cluster_ca_certificate = var.ca
}
provider "aws" {
  region = var.aws_region
}

# TODO: check if we can configure health checks
resource "kubernetes_service" "controller_public_svc" {

  wait_for_load_balancer = true
  metadata {
    name      = "controller-public-service"
    namespace = "controller-cos-controller"
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-scheme" : "internet-facing",
    }
  }
  spec {
    selector = {
      "app.kubernetes.io/name" = "controller"
    }
    port {
      port        = 17070
      target_port = 17070
    }
    type                = "LoadBalancer"
    load_balancer_class = "eks.amazonaws.com/nlb"
  }

}


data "aws_lb" "controller_public_nlb" {
  tags = {
    "service.eks.amazonaws.com/stack" = "${kubernetes_service.controller_public_svc.metadata[0].namespace}/${kubernetes_service.controller_public_svc.metadata[0].name}"
  }

}

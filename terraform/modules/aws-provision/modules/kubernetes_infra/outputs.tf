output "controller-public-address" {
  value = "${data.aws_lb.controller_public_nlb.dns_name}:17070"
}

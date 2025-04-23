
variable "region" {
  description = "The AWS region where the resources will be provisioned."
  type        = string
}

variable "cos-cloud-name" {
  description = "The name to assign to the Kubernetes cloud when running 'juju add-k8s'."
  type        = string
  default     = "cos-cloud"
}

variable "cos-controller-name" {
  description = "The name to assign to the Juju controller that will manage COS."
  type        = string
  default     = "cos-controller"
}

variable "cos-model-name" {
  description = "The name of the Juju model where COS will be deployed."
  type        = string
  default     = "cos"
}

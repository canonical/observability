
variable "region" {
  description = "The AWS region where the resources will be provisioned."
  type        = string
}

variable "cos_cloud_name" {
  description = "The name to assign to the Kubernetes cloud when running 'juju add-k8s'."
  type        = string
  default     = "cos-cloud"
}

variable "cos_controller_name" {
  description = "The name to assign to the Juju controller that will manage COS."
  type        = string
  default     = "cos-controller"
}

variable "cos_model_name" {
  description = "The name of the Juju model where COS will be deployed."
  type        = string
  default     = "cos"
}

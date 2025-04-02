variable "region" {
  description = "The AWS region to deploy resources in"
  type    = string
  default = "ap-southeast-1"
}

variable "output_private_key" {
  description = "Output the private key"
  type    = bool
  default = true
}
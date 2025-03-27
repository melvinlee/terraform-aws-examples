variable "associate_public_ip" {
  description = "Whether to associate a public IP address with the instance"
  type        = bool
  default     = true
}

variable "allow_ssh" {
  description = "Allow SSH access to the instance"
  type        = bool
  default     = false       
}

variable "attach_ebs_volume" {
  description = "Whether to attach the EBS volume to the EC2 instance"
  type        = bool
  default     = false
}
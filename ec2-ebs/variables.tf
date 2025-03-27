variable "associate_public_ip" {
  description = "Whether to associate a public IP address with the instance"
  type        = bool
  default     = false
}

variable "allow_ssh" {
  description = "Allow SSH access to the instance"
  type        = bool
  default     = false       
}
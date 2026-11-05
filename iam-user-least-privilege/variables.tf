variable "region" {
  type        = string
  description = "AWS region used by the provider."
  default     = "ap-southeast-1"
}

variable "user_name" {
  type        = string
  description = "Name of the IAM user. The user has no permissions except to assume the two roles."
  default     = "least-privilege-operator"

  validation {
    condition     = length(var.user_name) >= 1 && length(var.user_name) <= 50
    error_message = "user_name must be 1 to 50 characters so the role names stay within the 64 character IAM limit."
  }
}

variable "max_session_duration" {
  type        = number
  description = "Maximum session duration in seconds for both roles."
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "max_session_duration must be between 3600 and 43200 seconds."
  }
}

variable "ownership_tag_key" {
  type        = string
  description = "Tag key that marks EC2 resources the developer role may manage."
  default     = "managed_by"

  validation {
    condition     = !startswith(lower(var.ownership_tag_key), "aws:")
    error_message = "ownership_tag_key must not start with the reserved aws: prefix."
  }
}

variable "allowed_tag_keys" {
  type        = list(string)
  description = "Additional tag keys the developer role may set at creation, besides the ownership tag key and Name. Must include every key in the provider default_tags, or launches fail."
  default     = ["project", "provisioned_with"]
}

variable "ownership_tag_value" {
  type        = string
  description = "Tag value that marks EC2 resources the developer role may manage."
  default     = "developer-role"
}

variable "instance_profile_role_arns" {
  type        = list(string)
  description = "ARNs of roles the developer role may pass to EC2 (iam:PassRole, only to ec2.amazonaws.com). Empty means no PassRole permission."
  default     = []

  validation {
    condition     = alltrue([for arn in var.instance_profile_role_arns : can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:role/[^*]+$", arn))])
    error_message = "Each entry must be a role ARN like arn:aws:iam::123456789012:role/name, without wildcards."
  }
}

variable "eks_cluster_arns" {
  type        = list(string)
  description = "ARNs of EKS clusters the developer role may modify (nodegroup config and Kubernetes API access). Empty means no mutating EKS access."
  default     = []

  validation {
    condition     = alltrue([for arn in var.eks_cluster_arns : can(regex("^arn:aws[a-z-]*:eks:[a-z0-9-]+:[0-9]{12}:cluster/[A-Za-z0-9_-]+$", arn))])
    error_message = "Each entry must be a cluster ARN like arn:aws:eks:ap-southeast-1:123456789012:cluster/name, without wildcards."
  }
}

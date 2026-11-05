output "user_arn" {
  description = "ARN of the IAM user."
  value       = aws_iam_user.operator.arn
}

output "read_only_role_arn" {
  description = "ARN of the read-only role."
  value       = aws_iam_role.read_only.arn
}

output "developer_role_arn" {
  description = "ARN of the developer role."
  value       = aws_iam_role.developer.arn
}

output "read_only_switch_role_url" {
  description = "Console URL that switches to the read-only role."
  value       = "https://signin.aws.amazon.com/switchrole?account=${data.aws_caller_identity.current.account_id}&roleName=${aws_iam_role.read_only.name}&displayName=${aws_iam_role.read_only.name}"
}

output "developer_switch_role_url" {
  description = "Console URL that switches to the developer role."
  value       = "https://signin.aws.amazon.com/switchrole?account=${data.aws_caller_identity.current.account_id}&roleName=${aws_iam_role.developer.name}&displayName=${aws_iam_role.developer.name}"
}

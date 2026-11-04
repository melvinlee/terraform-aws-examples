output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "region" {
  description = "AWS region"
  value       = local.region
}

output "node_iam_role_name" {
  description = "Name of the IAM role assigned to Karpenter-provisioned nodes"
  value       = module.karpenter.node_iam_role_name
}

output "kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${local.region} --name ${module.eks.cluster_name}"
}

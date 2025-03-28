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

output "kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${local.region} --name ${module.eks.cluster_name}"
}

output "target_group_arn" {
  description = "ARN of the Nginx target group"
  value       = aws_lb_target_group.nginx.arn
}

output "load_balancer_dns" {
  description = "DNS name of the Nginx load balancer"
  value       = aws_lb.nginx.dns_name
}
# EKS Fargate with External Load Balancer Example

This example demonstrates how to deploy an Amazon EKS cluster using AWS Fargate as the compute provider, along with a Nginx application running on the cluster and expose Nginx via Load Balancer.

## Prerequisites

- AWS CLI installed and configured
- Terraform/OpenTofu installed
- kubectl installed

## Architecture

This example sets up the following components:

- A VPC with public and private subnets across 3 availability zones
- An Amazon EKS cluster with Fargate profiles for:
  - A dedicated `nginx` namespace
- A managed node group with t3.micro EC2 instances for workloads that cannot run on Fargate
- A Nginx deployment with 2 replicas and targetgroupbinding in the `nginx` namespace
- A Kubernetes service to expose the Nginx deployment within the cluster
- An optional ingress resource for external access

## Deployment

1. Initialize the Terraform working directory:

```bash
terraform init
```

2. Review the planned changes:

```bash
terraform plan
```

3. Apply the configuration:

```bash
terraform apply
```

4. After successful deployment, configure kubectl to access your EKS cluster:

```bash
# The command will be provided in the terraform output
aws eks update-kubeconfig --region <region> --name <cluster_name>
```

5. Deploy nginx

```bash
kubectl apply -f nginx/deployment.yaml
```

## Verification

To verify that Nginx is running:

```bash
kubectl get pods -n nginx
kubectl get services -n nginx
```

## Accessing the Nginx Service

### Within the cluster
The Nginx application is accessible within the cluster at: `http://nginx.nginx.svc.cluster.local`

### External access
If you've enabled the ALB Ingress Controller and deployed the provided ingress resource, you can access Nginx through the ALB address. Get the ingress address:

```bash
kubectl get ingress -n nginx
```

## Cleanup

To delete all resources created by this example:

```bash
terraform destroy
```

## Notes

- AWS Fargate eliminates the need to manage EC2 instances for your EKS workloads
- The t3.small node group provides compute capacity for workloads that require EC2 instances
- This example uses the latest Nginx image; you can modify the version in the kubernetes.tf file
- Resource requests and limits can be adjusted based on your workload requirements
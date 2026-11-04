# Terraform AWS Examples [![Devbox Ready](https://img.shields.io/badge/Devbox-Ready-blue)](https://www.jetpack.io/devbox/)

A collection of Terraform modules demonstrating various AWS infrastructure patterns and best practices.


## Overview

This repository contains example Terraform configurations for provisioning different AWS resources. Each directory contains a standalone module that can be used as a reference for implementing specific AWS infrastructure patterns.

## Modules

| Module | Description | Key features |
|--------|-------------|--------------|
| [`auto-scaling-group/`](./auto-scaling-group/) | Auto Scaling Group with launch templates and scaling policies | Launch template, scaling policies |
| [`ec2/`](./ec2/) | Basic EC2 instance provisioning | Security groups, SSH key management |
| [`ec2-ebs/`](./ec2-ebs/) | EC2 instance with an additional EBS volume | 20GB volume mounted at `/data`, Ansible formatting/mounting, deployment logging, SSM access |
| [`eks-fargate/`](./eks-fargate/) | EKS cluster using Fargate profiles | Serverless Kubernetes, custom VPC with private/public subnets, example Nginx deployment |
| [`eks-fargate-lb/`](./eks-fargate-lb/) | `eks-fargate` extended with an Application Load Balancer | ALB with security groups, Nginx target group, public endpoint, health checks |
| [`eks-karpenter-bottlerocket/`](./eks-karpenter-bottlerocket/) | EKS cluster where Karpenter provisions Bottlerocket nodes | Pod Identity, managed node group for the controller, `EC2NodeClass`/`NodePool` manifests, read-only console user |
| [`elasticsearch-multi-az/`](./elasticsearch-multi-az/) | Elasticsearch cluster across multiple availability zones | High availability |
| [`elasticsearch-single-az/`](./elasticsearch-single-az/) | Single-AZ Elasticsearch deployment | Security groups, SSM integration |
| [`rds-oracle/`](./rds-oracle/) | RDS Oracle Enterprise Edition 19c instance | BYOL, custom parameter/option groups, STATSPACK, enhanced monitoring |

## Development Environment

This project uses [devbox](https://www.jetpack.io/devbox/) to create a consistent development environment with all necessary tools.

### Prerequisites

- Install devbox: https://www.jetpack.io/devbox/docs/installing_devbox/

### Included Tools

The devbox environment includes:
- OpenTofu (Terraform compatible)
- kubectl
- Helm
- k9s

### Getting Started with Devbox

1. Initialize the devbox environment:
   ```
   devbox shell
   ```

2. This will automatically install all required tools and dependencies

3. Verify installations:
   ```
   tofu --version
   kubectl version --client
   helm version
   k9s version
   ```

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform/OpenTofu v0.19+ installed
- Basic understanding of AWS services and Terraform

## Usage

Each module is independent and can be used separately. To use a specific module:

1. Navigate to the module directory
2. Initialize the Terraform configuration:
   ```
   tofu init
   ```
3. Review and modify the configuration as needed
4. Apply the Terraform configuration:
   ```
   tofu apply
   ```

## Structure

Each module typically includes:
- `main.tf` - Main Terraform configuration
- `variables.tf` - Input variables
- `outputs.tf` - Output values
- `data.tf` or `data-source.tf` - Data sources
- Specific resource configurations (e.g., `ec2-sg.tf`, `elasticsearch.tf`)
- `README.md` - Module-specific documentation

## Best Practices Demonstrated

- Resource organization and module structure
- Security group configuration
- IAM role management
- Data encryption
- High availability patterns
- Infrastructure automation

## License

This project is provided for educational and reference purposes. Review and customize the configurations before using in production environments.
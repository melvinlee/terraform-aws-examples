# Terraform AWS Examples

A collection of Terraform modules demonstrating various AWS infrastructure patterns and best practices.

## Overview

This repository contains example Terraform configurations for provisioning different AWS resources. Each directory contains a standalone module that can be used as a reference for implementing specific AWS infrastructure patterns.

## Modules

### Auto Scaling Group
- **Path**: [`auto-scaling-group/`](./auto-scaling-group/)
- **Description**: Demonstrates how to create an Auto Scaling Group with launch templates and scaling policies.

### EC2 Instance
- **Path**: [`ec2/`](./ec2/)
- **Description**: Basic EC2 instance provisioning with security groups and SSH key management.

### EC2 with EBS Volume
- **Path**: [`ec2-ebs/`](./ec2-ebs/)
- **Description**: Provisions an EC2 instance with an additional EBS volume, including Ansible integration for automated volume mounting.
- **Features**:
  - Attaches and mounts a 20GB EBS volume to `/data`
  - Includes automated formatting and mounting via Ansible playbooks
  - Configures logging for deployment processes
  - Uses SSM for secure instance management

### Elasticsearch Multi-AZ
- **Path**: [`elasticsearch-multi-az/`](./elasticsearch-multi-az/)
- **Description**: Deploys an Elasticsearch cluster across multiple availability zones for high availability.

### Elasticsearch Single-AZ
- **Path**: [`elasticsearch-single-az/`](./elasticsearch-single-az/)
- **Description**: Sets up a single-AZ Elasticsearch deployment with security groups and SSM integration.

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform v0.12+ installed
- Basic understanding of AWS services and Terraform

## Usage

Each module is independent and can be used separately. To use a specific module:

1. Navigate to the module directory
2. Initialize the Terraform configuration:
   ```
   terraform init
   ```
3. Review and modify the configuration as needed
4. Apply the Terraform configuration:
   ```
   terraform apply
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
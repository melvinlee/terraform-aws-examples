# EC2 Instance with EBS Volume

This Terraform module provisions an Amazon EC2 instance with an additional EBS volume in AWS. The module demonstrates how to create and attach additional block storage to EC2 instances for data persistence.

## Features

- Deploys an Amazon EC2 instance running Amazon Linux 2
- Creates and attaches an additional EBS volume (20GB)
- Configures security group with SSH access
- Sets up AWS Systems Manager (SSM) for secure instance management
- Includes user data script to install and configure Ansible
- Uses encrypted EBS volumes for enhanced security

## Architecture

The module deploys the following resources:

- **EC2 Instance**: t3.micro running the latest Amazon Linux 2 AMI
- **EBS Volume**: 20GB GP2 encrypted volume attached as `/dev/sdf`
- **Security Group**: Allows SSH access from anywhere (can be restricted)
- **IAM Role & Instance Profile**: Enables SSM Session Manager access
- **VPC & Subnet**: Uses the default VPC and a subnet from it

## Prerequisites

- AWS credentials configured
- Terraform v0.12+
- Default VPC available in the target region

## Usage

```hcl
module "ec2_with_ebs" {
  source = "path/to/ec2-ebs"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| No variables defined in the current configuration | | | | |

## Outputs

| Name | Description |
|------|-------------|
| instance_public_ip | The public IP address of the EC2 instance |
| ebs_volume_id | The ID of the attached EBS volume |

## User Data Script

The instance runs a bootstrap script that:
1. Updates the system packages
2. Installs Python 3 and pip
3. Installs Ansible and AWS collections
4. Creates and runs a playbook to install AWS dependencies

## Security Considerations

- SSH access is allowed from anywhere (0.0.0.0/0) but can be restricted
- The EBS volumes are encrypted by default
- AWS Systems Manager (SSM) is configured for secure instance management

## Customization

To customize this module:
- Edit the `main.tf` to change instance type or EBS volume size
- Modify the `user-data.sh` script to customize instance bootstrapping
- Restrict the security group rules for production use

## License

This module is provided as an example and is not intended for production use without appropriate security reviews.
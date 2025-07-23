data "aws_availability_zones" "available" {}

locals {
  name   = "eks-fargate"
  region = "ap-southeast-1"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Name      = local.name
    ManagedBy = "Terraform"
  }
}

################################################################################
# EKS Module
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  cluster_name                   = local.name
  cluster_version                = "1.32"
  cluster_endpoint_public_access = true

  # Disable all control plane logging
  cluster_enabled_log_types = []

  # Explicitly disable etcd encryption
  create_kms_key            = false
  cluster_encryption_config = {}

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  # Fargate profiles
  fargate_profiles = {
    default = {
      name = "default"
      selectors = [
        {
          namespace = "default"
        },
        {
          namespace = "kube-system"
        }
      ]
    }
    nginx = {
      name = "nginx"
      selectors = [
        {
          namespace = "nginx"
        }
      ]
    }
  }

  tags = local.tags
}
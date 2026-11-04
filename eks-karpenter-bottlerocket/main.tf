data "aws_availability_zones" "available" {}

# Newest Kubernetes version that EKS offers with standard support
data "aws_eks_cluster_versions" "supported" {
  version_status = "STANDARD_SUPPORT"
}

locals {
  cluster_version = "1.${max([for version in data.aws_eks_cluster_versions.supported.cluster_versions : tonumber(split(".", version.cluster_version)[1])]...)}"

  name   = "eks-karpenter-bottlerocket"
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
  version = "~> 20.0"

  cluster_name                             = local.name
  cluster_version                          = local.cluster_version
  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
    # Required by Karpenter to obtain AWS credentials through EKS Pod Identity
    eks-pod-identity-agent = {}
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  # Small Bottlerocket node group that only runs the Karpenter controller.
  # Karpenter cannot run on Fargate because Pod Identity is not supported there.
  eks_managed_node_groups = {
    controller = {
      ami_type       = "BOTTLEROCKET_ARM_64"
      instance_types = ["t4g.medium"]

      min_size     = 1
      max_size     = 1
      desired_size = 1

      labels = {
        "karpenter.sh/controller" = "true"
      }

      taints = {
        critical_addons = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }

  # Karpenter selects the security group for new nodes through this tag
  node_security_group_tags = {
    "karpenter.sh/discovery" = local.name
  }

  tags = local.tags
}

################################################################################
# Karpenter
################################################################################

# Controller IAM role (Pod Identity), node IAM role, SQS interruption queue and EventBridge rules
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.0"

  cluster_name = module.eks.cluster_name

  # Associates the controller role with the Karpenter service account
  create_pod_identity_association = true

  # The node role is referenced by name from the EC2NodeClass
  node_iam_role_use_name_prefix = false
  node_iam_role_name            = "${local.name}-node"

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.tags
}

resource "helm_release" "karpenter" {
  name             = "karpenter"
  namespace        = "kube-system"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = "1.6.0"
  wait             = true
  create_namespace = false

  values = [
    yamlencode({
      settings = {
        clusterName       = module.eks.cluster_name
        clusterEndpoint   = module.eks.cluster_endpoint
        interruptionQueue = module.karpenter.queue_name
      }
      serviceAccount = {
        name = module.karpenter.service_account
      }
      tolerations = [
        {
          key      = "CriticalAddonsOnly"
          operator = "Exists"
        }
      ]
      nodeSelector = {
        "karpenter.sh/controller" = "true"
      }
    })
  ]
}

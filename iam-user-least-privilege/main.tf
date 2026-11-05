# Account ID, used to build the role-switch URLs and resource ARNs
data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # ARN prefix for EC2 resources in the configured region and account
  ec2_arn_prefix = "arn:aws:ec2:${var.region}:${local.account_id}"

  # Nodegroup ARNs (arn:...:nodegroup/<cluster>/<nodegroup>/<id>) for each allowed cluster
  eks_nodegroup_arns = [
    for arn in var.eks_cluster_arns :
    "${replace(arn, ":cluster/", ":nodegroup/")}/*/*"
  ]
}

# The only identity policy on this user is the assume-role policy defined
# below (no attached managed policies). Access keys are not created by this
# module. Create the console password manually, outside Terraform, so it never
# lands in state.
resource "aws_iam_user" "operator" {
  name = var.user_name

  # Lets destroy succeed even if a console password or other credentials were added outside Terraform
  force_destroy = true
}

# Trust policy shared by both roles: only the user may assume them
data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.operator.arn]
    }
  }
}

# Read-only role
resource "aws_iam_role" "read_only" {
  name                 = "${var.user_name}-read-only"
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = var.max_session_duration
}

resource "aws_iam_role_policy_attachment" "read_only" {
  role       = aws_iam_role.read_only.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Scoped write permissions for deploying EC2 and EKS workloads
data "aws_iam_policy_document" "developer" {
  # Some Describe calls are global, so no region condition here
  statement {
    sid       = "Ec2Describe"
    effect    = "Allow"
    actions   = ["ec2:Describe*"]
    resources = ["*"]
  }

  # Instances can only be launched when the request carries the ownership tag
  statement {
    sid       = "Ec2RunInstances"
    effect    = "Allow"
    actions   = ["ec2:RunInstances"]
    resources = ["${local.ec2_arn_prefix}:instance/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/${var.ownership_tag_key}"
      values   = [var.ownership_tag_value]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.region]
    }
  }

  # Other resources used by RunInstances; they cannot carry the instance tag condition
  statement {
    sid     = "Ec2RunInstancesSupportingResources"
    effect  = "Allow"
    actions = ["ec2:RunInstances"]
    resources = [
      "arn:aws:ec2:${var.region}::image/*",
      "${local.ec2_arn_prefix}:subnet/*",
      "${local.ec2_arn_prefix}:security-group/*",
      "${local.ec2_arn_prefix}:network-interface/*",
      "${local.ec2_arn_prefix}:volume/*",
      "${local.ec2_arn_prefix}:key-pair/*",
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.region]
    }
  }

  # Lifecycle actions only on instances that carry the ownership tag
  statement {
    sid    = "Ec2InstanceControl"
    effect = "Allow"
    actions = [
      "ec2:StartInstances",
      "ec2:StopInstances",
      "ec2:RebootInstances",
      "ec2:TerminateInstances",
    ]
    resources = ["${local.ec2_arn_prefix}:instance/*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/${var.ownership_tag_key}"
      values   = [var.ownership_tag_value]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.region]
    }
  }

  # Tags can only be set while creating a resource, never on existing ones
  statement {
    sid       = "Ec2TagOnCreate"
    effect    = "Allow"
    actions   = ["ec2:CreateTags"]
    resources = ["${local.ec2_arn_prefix}:*/*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["RunInstances", "CreateSecurityGroup"]
    }
    condition {
      test     = "ForAllValues:StringEquals"
      variable = "aws:TagKeys"
      values   = concat([var.ownership_tag_key, "Name"], var.allowed_tag_keys)
    }
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.region]
    }
  }

  # Security groups can only be created with the ownership tag
  statement {
    sid       = "Ec2CreateSecurityGroup"
    effect    = "Allow"
    actions   = ["ec2:CreateSecurityGroup"]
    resources = ["${local.ec2_arn_prefix}:security-group/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/${var.ownership_tag_key}"
      values   = [var.ownership_tag_value]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.region]
    }
  }

  # CreateSecurityGroup also needs the VPC it is created in
  statement {
    sid       = "Ec2CreateSecurityGroupVpc"
    effect    = "Allow"
    actions   = ["ec2:CreateSecurityGroup"]
    resources = ["${local.ec2_arn_prefix}:vpc/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.region]
    }
  }

  # Rule changes and deletion only on security groups that carry the ownership tag
  statement {
    sid    = "Ec2SecurityGroupManage"
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:DeleteSecurityGroup",
    ]
    resources = ["${local.ec2_arn_prefix}:security-group/*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/${var.ownership_tag_key}"
      values   = [var.ownership_tag_value]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.region]
    }
  }

  # Optional: pass instance profile roles to EC2 only
  dynamic "statement" {
    for_each = length(var.instance_profile_role_arns) > 0 ? [1] : []
    content {
      sid       = "PassInstanceProfileRoles"
      effect    = "Allow"
      actions   = ["iam:PassRole"]
      resources = var.instance_profile_role_arns
      condition {
        test     = "StringEquals"
        variable = "iam:PassedToService"
        values   = ["ec2.amazonaws.com"]
      }
    }
  }

  # Read access to EKS stays region-limited
  statement {
    sid    = "EksRead"
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters",
      "eks:DescribeNodegroup",
      "eks:ListNodegroups",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.region]
    }
  }

  # Mutating EKS access only on the allowed clusters; omitted when the list is empty
  dynamic "statement" {
    for_each = length(var.eks_cluster_arns) > 0 ? [1] : []
    content {
      sid       = "EksAccessKubernetesApi"
      effect    = "Allow"
      actions   = ["eks:AccessKubernetesApi"]
      resources = var.eks_cluster_arns
    }
  }

  dynamic "statement" {
    for_each = length(var.eks_cluster_arns) > 0 ? [1] : []
    content {
      sid       = "EksUpdateNodegroupConfig"
      effect    = "Allow"
      actions   = ["eks:UpdateNodegroupConfig"]
      resources = local.eks_nodegroup_arns
    }
  }
}

resource "aws_iam_policy" "developer" {
  name        = "${var.user_name}-developer"
  description = "Scoped EC2 and EKS permissions for the developer role."
  policy      = data.aws_iam_policy_document.developer.json
}

# Developer role
resource "aws_iam_role" "developer" {
  name                 = "${var.user_name}-developer"
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = var.max_session_duration
}

resource "aws_iam_role_policy_attachment" "developer" {
  role       = aws_iam_role.developer.name
  policy_arn = aws_iam_policy.developer.arn
}

# The only permission on the user: assume exactly these two roles
data "aws_iam_policy_document" "assume_roles" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    resources = [
      aws_iam_role.read_only.arn,
      aws_iam_role.developer.arn,
    ]
  }
}

resource "aws_iam_user_policy" "assume_roles" {
  name   = "assume-roles"
  user   = aws_iam_user.operator.name
  policy = data.aws_iam_policy_document.assume_roles.json
}

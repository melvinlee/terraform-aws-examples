################################################################################
# Console user
################################################################################

# IAM user for browsing the cluster in the AWS console. EKS access entries cannot
# grant access to the account root user. Create its console password separately.
resource "aws_iam_user" "console" {
  name          = "${local.name}-console"
  force_destroy = true

  tags = local.tags
}

resource "aws_iam_user_policy" "console" {
  name = "eks-console-read"
  user = aws_iam_user.console.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["eks:Describe*", "eks:List*", "eks:AccessKubernetesApi"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_service_linked_role" "es" {
  aws_service_name = "es.amazonaws.com"
}

resource "aws_elasticsearch_domain" "this" {
  domain_name           = "my-es"
  elasticsearch_version = "7.10"

  cluster_config {
    dedicated_master_enabled = false
    instance_count           = 2
    instance_type            = "r4.large.elasticsearch"
    zone_awareness_enabled   = true
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 30
  }

  vpc_options {
    subnet_ids = [
      tolist(data.aws_subnet_ids.default.ids)[0],
      tolist(data.aws_subnet_ids.default.ids)[1],
    ]

    security_group_ids = [aws_security_group.es.id]
  }

  advanced_options = {
    "rest.action.multi.allow_explicit_index" = "true"
  }

  access_policies = <<CONFIG
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "es:*",
            "Principal": "*",
            "Effect": "Allow",
            "Resource": "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/my-es/*"
        }
    ]
}
CONFIG

  tags = {
    Domain = "TestDomain"
  }

  depends_on = [aws_iam_service_linked_role.es]
}

resource "aws_iam_service_linked_role" "es" {
  aws_service_name = "es.amazonaws.com"
}

resource "aws_elasticsearch_domain" "this" {
  domain_name           = "my-es"
  elasticsearch_version = "7.10"

  cluster_config {
    dedicated_master_enabled = false
    instance_count           = 1
    instance_type            = "r4.large.elasticsearch"
    zone_awareness_enabled   = false
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 30
  }

  vpc_options {
    subnet_ids = [
      tolist(data.aws_subnets.default.ids)[0],
    ]

    security_group_ids = [aws_security_group.es.id]
  }

  advanced_options = {
    "rest.action.multi.allow_explicit_index" = "true"
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true
    master_user_options {
      master_user_name     = "esadmin"
      master_user_password = random_password.es-password.result
    }
  }

  node_to_node_encryption {
    enabled = true
  }

  encrypt_at_rest {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
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

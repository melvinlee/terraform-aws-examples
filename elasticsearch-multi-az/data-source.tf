data "aws_vpc" "default" {

  default = true

}

data "aws_subnet_ids" "default" {

  vpc_id = data.aws_vpc.default.id

}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

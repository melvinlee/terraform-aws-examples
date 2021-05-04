resource "random_password" "es-password" {
  length           = 16
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
  special          = true
  override_special = "_%@"
}

resource "aws_ssm_parameter" "es-password-ssm" {
  name  = "/elasticsearch/esadmin-password"
  type  = "String"
  value = random_password.es-password.result
}

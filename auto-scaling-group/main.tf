resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer2-key"
  public_key = tls_private_key.key.public_key_openssh
}

resource "aws_launch_configuration" "this" {
  count = var.create_asg ? 1 : 0

  name_prefix       = "myweb-lt-"
  image_id          = data.aws_ami.amazon_linux.id
  instance_type     = "t3.micro"
  user_data         = data.template_file.bootstrap.rendered
  enable_monitoring = false
  key_name          = aws_key_pair.deployer.key_name
  # security_groups   = ["sg-511da236"]

  ebs_block_device {
    device_name = "/dev/sdb"
    volume_type = "gp2"
    volume_size = 5
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg" {
  count = var.create_asg ? 1 : 0

  name_prefix      = "myweb-"
  max_size         = 3
  min_size         = 1
  desired_capacity = 2

  health_check_grace_period = 300
  force_delete              = true

  launch_configuration = aws_launch_configuration.this[0].name
  vpc_zone_identifier  = data.aws_subnet_ids.default.ids

}

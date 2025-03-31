resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer2-key"
  public_key = tls_private_key.key.public_key_openssh
}

resource "aws_launch_template" "this" {
  count = var.create_asg ? 1 : 0

  name_prefix   = "lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  user_data     = base64encode(data.template_file.bootstrap.rendered)
  ebs_optimized = true
  key_name      = aws_key_pair.deployer.key_name

  monitoring {
    enabled = true
  }

  # security_groups   = ["sg-511da236"]

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = 20
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg" {
  count = var.create_asg ? 1 : 0

  name_prefix      = "myweb"
  max_size         = 3
  min_size         = 1
  desired_capacity = 3

  health_check_grace_period = 300
  force_delete              = true
  vpc_zone_identifier       = data.aws_subnets.default.ids

  launch_template {
    id      = aws_launch_template.this[0].id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 30
    }
    triggers = ["tag"]
  }

  tag {
    key                 = "Name"
    value               = "nginx-web"
    propagate_at_launch = true
  }
  tag {
    key                 = "version"
    value               = "1.1"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_schedule" "stop" {
  count = var.create_asg ? 1 : 0

  scheduled_action_name  = "auto-stop"
  min_size               = 0
  max_size               = -1
  desired_capacity       = 0
  recurrence             = "0 14 * * *"
  autoscaling_group_name = aws_autoscaling_group.asg[0].name
}

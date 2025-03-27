# Security Group for EC2 instance
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-security-group"
  description = "Allow SSH inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  # SSH ingress rule that can be toggled using the allow_ssh variable
  dynamic "ingress" {
    for_each = var.allow_ssh ? [1] : []
    content {
      description = "SSH from Internet"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-security-group"
  }
}

# IAM role for SSM Session Manager
resource "aws_iam_role" "ssm_role" {
  name = "ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "ec2-ssm-role"
  }
}

# Attach SSM policy to the IAM role
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Create instance profile using the IAM role
resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "ec2-ssm-instance-profile"
  role = aws_iam_role.ssm_role.name
}

# Create an EC2 instance
resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = tolist(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_instance_profile.name
  user_data              = file("${path.module}/user-data.sh")

  # Use the variable to control public IP assignment
  associate_public_ip_address = var.associate_public_ip
  
  root_block_device {
    volume_size = 50
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "web-server"
  }
}

# Create an EBS volume
resource "aws_ebs_volume" "data_volume" {
  availability_zone = aws_instance.web_server.availability_zone
  size              = 20
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "data-volume"
  }
}

# Attach the EBS volume to the EC2 instance
resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data_volume.id
  instance_id = aws_instance.web_server.id
}

# Output the public IP of the EC2 instance
output "instance_public_ip" {
  value = aws_instance.web_server.public_ip
}

# Output the EBS volume ID
output "ebs_volume_id" {
  value = aws_ebs_volume.data_volume.id
}

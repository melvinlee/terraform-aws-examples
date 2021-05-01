data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name = "name"

    values = [
      "amzn-ami-hvm-*-x86_64-gp2",
    ]
  }

  filter {
    name = "owner-alias"

    values = [
      "amazon",
    ]
  }
}

resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = tls_private_key.key.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.key.private_key_pem
  filename        = "key.pem"
  file_permission = "0600"
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.deployer.key_name

  network_interface {
    network_interface_id = aws_network_interface.this.id
    device_index         = 0
  }

  tags = {
    Name = "my-ec2"
  }
}

resource "aws_network_interface" "this" {
  subnet_id       = element(tolist(data.aws_subnet_ids.default.ids), 0)
  security_groups = [aws_security_group.this.id]
  tags = {
    Name = "primary_network_interface"
  }
}

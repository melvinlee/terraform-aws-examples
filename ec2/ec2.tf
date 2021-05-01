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

output "private_key_pem" {
  value = var.output_private_key == true ? tls_private_key.key.private_key_pem : ""
  sensitive = true
}

output "public_dns" {
  value = aws_instance.web.public_dns
}

output "public_ip" {
  value = aws_instance.web.public_ip
}

output "ssh" {
  value = <<CONFIGURE
Run the following commands to ssh into the machine:
$ ssh -i "key.pem" user@<public_dns>
CONFIGURE

}

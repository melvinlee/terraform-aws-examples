output "private_key_pem" {
  value     = tls_private_key.key.private_key_pem
  sensitive = true
}
output "ssh" {
  value = <<CONFIGURE
Run the following commands to ssh into the machine:
$ ssh -i "key.pem" user@<public_dns>
CONFIGURE

}

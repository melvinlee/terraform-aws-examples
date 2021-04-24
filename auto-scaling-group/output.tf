output "ssh" {
  value = <<CONFIGURE
Run the following commands to ssh into the machine:
$ ssh -i "key.pem" user@<public_dns>
CONFIGURE

}

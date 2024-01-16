# Outputs file

output "public_key_pem" {
  value = tls_private_key.masa_key.public_key_pem
}

output "private_key_pem" {
  value     = tls_private_key.masa_key.private_key_pem
  sensitive = true
}

output "ssh_connection" {
  value = <<EOF

To connect to instance1:
ssh -i ${local.private_key_filename}.pem ubuntu@${aws_instance.instance1.public_dns}

To connect to instance2:
ssh -i ${local.private_key_filename}.pem ubuntu@${aws_instance.instance2.public_dns}

EOF
}

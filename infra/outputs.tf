output "public_ips" {
  value       = aws_instance.lab_ec2.*.public_ip
  description = "Public IPs for ASK docker VMs"
}

output "private_ips" {
  value = aws_instance.lab_ec2.*.private_ip
}

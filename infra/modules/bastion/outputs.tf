output "public_ip" {
  description = "Public IP of the bastion."
  value       = aws_instance.bastion.public_ip
}

output "instance_id" {
  description = "Instance ID of the bastion."
  value       = aws_instance.bastion.id
}
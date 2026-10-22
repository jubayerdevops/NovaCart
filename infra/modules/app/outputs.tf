output "launch_template_id" {
  description = "ID of the app launch template."
  value       = aws_launch_template.app.id
}

output "ami_id" {
  description = "AMI used by the app servers."
  value       = data.aws_ami.al2023.id
}

output "iam_role_name" {
  description = "IAM role attached to the app instances."
  value       = aws_iam_role.app.name
}

output "asg_name" {
  description = "Name of the Auto Scaling Group."
  value       = aws_autoscaling_group.app.name
}
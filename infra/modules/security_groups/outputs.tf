output "alb_sg_id" {
  description = "Security group ID for the ALB."
  value       = aws_security_group.alb.id
}

output "app_sg_id" {
  description = "Security group ID for the app instances."
  value       = aws_security_group.app.id
}

output "db_sg_id" {
  description = "Security group ID for RDS."
  value       = aws_security_group.db.id
}

output "bastion_sg_id" {
  description = "Security group ID for the bastion (null when disabled)."
  value       = one(aws_security_group.bastion[*].id)
}
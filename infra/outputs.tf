output "name_prefix" {
  description = "Prefix used for resource names in this environment."
  value       = local.name_prefix
}

output "aws_region" {
  description = "Region this environment is deployed into."
  value       = var.aws_region
}

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private (app) subnet IDs."
  value       = module.vpc.private_subnet_ids
}

output "database_subnet_ids" {
  description = "Database subnet IDs."
  value       = module.vpc.database_subnet_ids
}

output "security_group_ids" {
  description = "Security group IDs per tier."
  value = {
    alb     = module.security_groups.alb_sg_id
    app     = module.security_groups.app_sg_id
    db      = module.security_groups.db_sg_id
    bastion = module.security_groups.bastion_sg_id
  }
}

output "alb_dns_name" {
  description = "Open this in a browser: http://<alb_dns_name>"
  value       = module.alb.alb_dns_name
}

output "asg_name" {
  description = "Auto Scaling Group name."
  value       = module.app.asg_name
}

output "db_endpoint" {
  description = "RDS MySQL hostname."
  value       = module.rds.db_endpoint
}

output "db_secret_arn" {
  description = "Secrets Manager ARN for the DB master credentials (not the password)."
  value       = module.rds.db_secret_arn
}

output "assets_bucket_name" {
  description = "S3 bucket for product images."
  value       = module.s3.bucket_name
}

output "bastion_public_ip" {
  description = "Bastion public IP (null when disabled)."
  value       = one(module.bastion[*].public_ip)
}
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
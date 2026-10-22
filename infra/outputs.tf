output "name_prefix" {
  description = "Prefix used for resource names in this environment."
  value       = local.name_prefix
}

output "aws_region" {
  description = "Region this environment is deployed into."
  value       = var.aws_region
}
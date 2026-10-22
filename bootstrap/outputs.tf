output "state_bucket_name" {
  description = "S3 bucket for Terraform state."
  value       = module.backend.bucket_name
}

output "lock_table_name" {
  description = "DynamoDB table for state locking."
  value       = module.backend.lock_table_name
}
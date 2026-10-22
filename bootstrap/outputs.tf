output "state_bucket_name" {
  description = "S3 bucket for Terraform state."
  value       = module.backend.bucket_name
}

output "lock_table_name" {
  description = "DynamoDB table for state locking."
  value       = module.backend.lock_table_name
}

output "state_bucket_policy_json" {
  description = "The HTTPS-only policy attached to the state bucket (JSON)."
  value       = module.iam.state_bucket_policy_json
}

output "github_ci_role_arn" {
  description = "Role ARN to use in GitHub Actions."
  value       = module.iam.github_ci_role_arn
}
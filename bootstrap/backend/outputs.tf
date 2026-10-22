output "bucket_name" {
  description = "Name of the Terraform state bucket."
  value       = aws_s3_bucket.state.bucket
}

output "bucket_arn" {
  description = "ARN of the state bucket (the OIDC role will need it)."
  value       = aws_s3_bucket.state.arn
}

output "lock_table_name" {
  description = "Name of the Terraform state lock table."
  value       = aws_dynamodb_table.lock.name
}
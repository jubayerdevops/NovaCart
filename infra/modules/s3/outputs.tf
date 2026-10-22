output "bucket_name" {
  description = "Name of the assets bucket."
  value       = aws_s3_bucket.assets.bucket
}

output "bucket_arn" {
  description = "ARN of the assets bucket."
  value       = aws_s3_bucket.assets.arn
}
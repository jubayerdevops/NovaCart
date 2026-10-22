output "db_endpoint" {
  description = "Hostname the app connects to."
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "MySQL port."
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Initial database name."
  value       = aws_db_instance.this.db_name
}

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the master credentials (never the password itself)."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}
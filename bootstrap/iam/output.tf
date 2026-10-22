output "state_bucket_policy_json" {
  description = "The HTTPS-only policy attached to the state bucket (JSON)."
  value       = data.aws_iam_policy_document.state_tls_only.json
}

output "github_ci_role_arn" {
  description = "ARN of the role GitHub Actions assumes via OIDC."
  value       = aws_iam_role.github_ci.arn
}
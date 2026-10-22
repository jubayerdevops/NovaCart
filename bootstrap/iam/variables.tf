variable "project_name" {
  description = "Used in resource names."
  type        = string
}

variable "github_repo" {
  description = "GitHub repo allowed to assume the CI role, as owner/name."
  type        = string
}

variable "state_bucket_id" {
  description = "ID (name) of the Terraform state bucket."
  type        = string
}

variable "state_bucket_arn" {
  description = "ARN of the Terraform state bucket."
  type        = string
}
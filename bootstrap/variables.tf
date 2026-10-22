variable "aws_region" {
  description = "Region for the state bucket. Must match the main project's region."
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Used in resource names and tags."
  type        = string
  default     = "novacart"
}

variable "github_repo" {
  description = "GitHub repo allowed to assume the CI role, as owner/name."
  type        = string
  default     = "jubayerdevops/NovaCart"
}

variable "aws_profile" {
  description = "AWS profile to use for the bootstrap process."
  type        = string
  default     = null # null = "use whatever credentials the environment gives me [NovaCart/bootstrap/terraform.tfvars]"
}
variable "name_prefix" {
  description = "Prefix for the bucket name, e.g. novacart-dev."
  type        = string
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete a non-empty bucket (dev only)."
  type        = bool
  default     = false
}
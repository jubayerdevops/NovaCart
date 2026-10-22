locals {
  # Common prefix for all resource names, e.g. "novacart-dev"
  name_prefix = "${var.project_name}-${var.environment}"
}
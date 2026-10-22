locals {
  # Common prefix for all resource names, e.g. "novacart-dev"
  name_prefix = "${var.project_name}-${var.environment}"
}

# ---------------------------------------------------------------- M02: Networking

module "vpc" {
  source = "./modules/vpc"

  name_prefix        = local.name_prefix
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  single_nat_gateway = var.single_nat_gateway
}
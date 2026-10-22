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

# ---------------------------------------------------------------- M03: Security groups
module "security_groups" {
  source = "./modules/security_groups"

  name_prefix      = local.name_prefix
  vpc_id           = module.vpc.vpc_id
  enable_https     = var.enable_https
  enable_bastion   = var.enable_bastion
  allowed_ssh_cidr = var.allowed_ssh_cidr
}
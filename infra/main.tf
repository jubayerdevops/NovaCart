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

# ---------------------------------------------------------------- M04: Load balancer
module "alb" {
  source = "./modules/alb"

  name_prefix       = local.name_prefix
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security_groups.alb_sg_id
}

# ---------------------------------------------------------------- M04: App tier
module "app" {
  source = "./modules/app"

  name_prefix   = local.name_prefix
  environment   = var.environment
  instance_type = var.instance_type
  app_sg_id     = module.security_groups.app_sg_id

  private_subnet_ids = module.vpc.private_subnet_ids
  target_group_arn   = module.alb.target_group_arn

  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity
  cpu_target       = var.cpu_target
}
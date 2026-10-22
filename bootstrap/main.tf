module "backend" {
  source = "./backend"

  project_name = var.project_name
}

module "iam" {
  source = "./iam"

  project_name     = var.project_name
  github_repo      = var.github_repo
  state_bucket_id  = module.backend.bucket_name
  state_bucket_arn = module.backend.bucket_arn

  depends_on = [module.backend]
}
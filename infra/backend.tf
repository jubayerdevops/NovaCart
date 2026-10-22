# ----------------------------------------------------------------
# Remote state: S3 with encryption and native S3 locking.
#
# Commented out by default so `terraform init` works before the
# state bucket exists. To enable it:
#   1. Run bootstrap/ once (creates the bucket)
#   2. Replace <ACCOUNT_ID> below and uncomment the block
#   3. terraform init -migrate-state
# See README.md -> "Enabling remote state".
# ----------------------------------------------------------------

# terraform {
#   backend "s3" {
#     bucket       = "novacart-tfstate-063570950337"
#     key          = "terraform-3tier/dev/terraform.tfstate"
#     region       = "ap-southeast-1"
#     profile      = var.aws_profile
#     encrypt      = true
#     use_lockfile = true

#     # Legacy alternative to use_lockfile (deprecated):
#     # dynamodb_table = "novacart-tf-lock
#   }
# }

# ----------------------------------------------------------------
# Remote state: S3 with encryption and native S3 locking.
# Partial backend configuration — supplied at init time:
#   terraform init -backend-config=backend.hcl -backend-config=<env>.backend.hcl
#   backend.hcl        -> bucket, region, profile (personal, git-ignored)
#   <env>.backend.hcl  -> key (separate state file per environment)
# Backend blocks cannot use variables, so nothing here references var.*
# ----------------------------------------------------------------
terraform {
  backend "s3" {
    encrypt      = true # server-side encryption of the state file
    use_lockfile = true # S3-native locking (Terraform >= 1.10)

    # Legacy alternative to use_lockfile (deprecated):
    # dynamodb_table = "novacart-tf-lock"
  }
}
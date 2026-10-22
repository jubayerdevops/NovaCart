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
#     bucket       = "novacart-tfstate-<ACCOUNT_ID>"
#     key          = "terraform-3tier/dev/terraform.tfstate"
#     region       = "ap-southeast-1"
#     encrypt      = true # server-side encryption of the state file
#     use_lockfile = true # S3-native locking (Terraform >= 1.10)
#
#     # Legacy alternative to use_lockfile (deprecated):
#     # dynamodb_table = "novacart-tf-lock"
#   }
# }
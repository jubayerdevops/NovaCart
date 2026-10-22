# Bootstrap — Terraform Remote State

One-time setup that creates the resources the main NovaCart project depends on.
Run this **once per AWS account**, before anything else.

## Why a separate folder?

The main project stores its state in S3, but that bucket must exist *before*
the main project can use it. Terraform can't keep its state in a bucket it
hasn't created yet, so this small project creates the bucket and keeps its own
state **locally**.

> The assignment says to create the state bucket manually. It is created with
> Terraform instead, so the setup is reproducible, reviewed in Git and never
> "clicked by hand".

## What it creates

| Resource | Name | Purpose |
|---|---|---|
| S3 bucket | `novacart-tfstate-<ACCOUNT_ID>` | Stores the main project's state |
| ├ Versioning | Enabled | Restore an older state if one gets corrupted |
| ├ Encryption | SSE-S3 (AES256) | State is encrypted at rest |
| ├ Public access block | All 4 settings on | Bucket can never be made public |
| └ `prevent_destroy` | true | Terraform refuses to delete it |
| DynamoDB table | `novacart-tf-lock` | State locking (legacy method, see below) |

## Structure

```
bootstrap/
├── versions.tf          # Terraform + AWS provider versions
├── providers.tf         # region, profile, default tags
├── variables.tf         # inputs
├── main.tf              # calls the modules
├── outputs.tf           # values printed after apply
├── terraform.tfvars     # your local values (git-ignored)
└── backend/             # module: state bucket + lock table
```

## Prerequisites

- Terraform >= 1.10
- AWS CLI configured with a profile (not the root user)

## Usage

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars   # set aws_profile
terraform init
terraform plan
terraform apply
```

Outputs:

```
lock_table_name   = "novacart-tf-lock"
state_bucket_name = "novacart-tfstate-<ACCOUNT_ID>"
```

Use these values in the main project's `backend.tf`.

## Variables

| Name | Default | Description |
|---|---|---|
| `aws_region` | `ap-southeast-1` | Must match the main project's region |
| `project_name` | `novacart` | Prefix for resource names |
| `aws_profile` | `null` | AWS CLI profile; set it in `terraform.tfvars` |
| `github_repo` | `jubayerdevops/NovaCart` | Repo allowed to use the CI role (OIDC) |

## Locking: S3 lockfile vs DynamoDB

Since Terraform 1.10, S3 can lock state by itself (`use_lockfile = true`), and
HashiCorp has deprecated DynamoDB-based locking. The main project uses
`use_lockfile`. The DynamoDB table is kept to demonstrate the older method.

## ⚠️ Local state

This folder's `terraform.tfstate` is stored **locally** and is git-ignored.
Back it up. If it's lost, Terraform forgets it created these resources (they
keep existing in AWS, and you'd have to `terraform import` them).

## Teardown

Destroy the main project first, then this. Because of `prevent_destroy`,
you must first set it to `false` in `backend/main.tf`, and empty the bucket
(including all object versions), then:

```bash
terraform destroy
```
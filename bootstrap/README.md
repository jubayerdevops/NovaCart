# Bootstrap — Remote State & GitHub OIDC

One-time setup that creates the resources the main NovaCart project depends on.
Run this **once per AWS account**, before anything else.

## Why a separate folder?

The main project stores its state in S3, but that bucket must exist *before*
the main project can use it. Terraform can't keep its state in a bucket it
hasn't created yet, so this small project creates the bucket and keeps its own
state **locally**.

It also creates the GitHub OIDC role, so CI can access AWS without stored keys.

> The assignment says to create the state bucket manually. It is created with
> Terraform instead, so the setup is reproducible, reviewed in Git and never
> "clicked by hand".

## What it creates

| Module | Resource | Name / Setting | Purpose |
|---|---|---|---|
| `backend` | S3 bucket | `novacart-tfstate-<ACCOUNT_ID>` | Stores the main project's state |
| `backend` | ├ Versioning | Enabled | Restore an older state if one gets corrupted |
| `backend` | ├ Encryption | SSE-S3 (AES256) | State is encrypted at rest |
| `backend` | ├ Public access block | All 4 settings on | Bucket can never be made public |
| `backend` | └ `prevent_destroy` | true | Terraform refuses to delete it |
| `backend` | DynamoDB table | `novacart-tf-lock` | State locking (legacy method, see below) |
| `iam` | S3 bucket policy | `DenyInsecureTransport` | Rejects any request not using HTTPS (encryption in transit) |
| `iam` | GitHub OIDC provider | `token.actions.githubusercontent.com` | Lets AWS trust tokens issued by GitHub Actions |
| `iam` | IAM role | `novacart-github-ci` | Assumed only by `jubayerdevops/NovaCart` workflows |
| `iam` | ├ Managed policy | `ReadOnlyAccess` | Can read all resources (for `terraform plan`), change nothing |
| `iam` | └ Inline policy | `terraform-state-access` | Read state + create/remove the lock file |

## Structure

```
bootstrap/
├── versions.tf               # Terraform + AWS provider versions
├── provider.tf               # region, profile, default tags
├── variables.tf              # inputs
├── main.tf                   # calls the modules
├── outputs.tf                # values printed after apply
├── terraform.tfvars.example  # copy to terraform.tfvars
├── terraform.tfvars          # your local values (git-ignored)
├── backend/                  # module: state bucket + lock table
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
└── iam/                      # module: bucket policy + GitHub OIDC role
    ├── main.tf
    ├── variables.tf
    └── output.tf
```

### How the modules connect

```
                 ┌──────────────────────────────┐
 project_name ──▶│ backend                      │
                 │  bucket, versioning, SSE,    │
                 │  public access block, table  │
                 └──────────────┬───────────────┘
                                │ bucket_name, bucket_arn
                                ▼
 project_name ──▶┌──────────────────────────────┐
 github_repo  ──▶│ iam                          │
                 │  bucket policy, OIDC         │
                 │  provider, CI role           │
                 └──────────────┬───────────────┘
                                │ github_ci_role_arn
                                ▼
                         root outputs
```

`main.tf` passes the bucket's name and ARN from `module.backend` into
`module.iam`, and `depends_on = [module.backend]` makes sure the bucket and
its public access block exist before the policy is attached.

## Prerequisites

- Terraform >= 1.10
- AWS CLI configured with a profile (not the root user)
- An AWS account with **no existing** GitHub OIDC provider
  (only one per account is allowed)

## Usage

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars   # set aws_profile
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

Outputs:

```
github_ci_role_arn       = "arn:aws:iam::<ACCOUNT_ID>:role/novacart-github-ci"
lock_table_name          = "novacart-tf-lock"
state_bucket_name        = "novacart-tfstate-<ACCOUNT_ID>"
state_bucket_policy_json = <the HTTPS-only policy>
```

- `state_bucket_name` goes into the main project's `backend.tf`
- `github_ci_role_arn` goes into the GitHub Actions workflow

## Variables

| Name | Default | Description |
|---|---|---|
| `aws_region` | `ap-southeast-1` | Must match the main project's region |
| `project_name` | `novacart` | Prefix for resource names |
| `aws_profile` | `null` | AWS CLI profile; set it in `terraform.tfvars` |
| `github_repo` | `jubayerdevops/NovaCart` | Only repo allowed to assume the CI role |

## GitHub Actions (OIDC)

No AWS access keys are stored in GitHub. Each workflow run exchanges a
short-lived GitHub token for **1-hour** AWS credentials:

```
GitHub Actions ──(signed token)──▶ AWS OIDC provider: is it really GitHub?
                                   IAM role trust policy: is it our repo?
               ◀──(1-hour keys)──  STS
```

Workflow usage:

```yaml
permissions:
  id-token: write   # allow the workflow to request an OIDC token
  contents: read

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::<ACCOUNT_ID>:role/novacart-github-ci
      aws-region: ap-southeast-1
```

The trust policy checks two claims in the GitHub token:

| Claim | Must equal | Why |
|---|---|---|
| `aud` | `sts.amazonaws.com` | Token was issued for AWS, not another service |
| `sub` | `repo:jubayerdevops/NovaCart:*` | Only this repo (any branch / PR); no other repo can assume the role |

**Least privilege:** the role is read-only by design. CI runs `fmt`,
`validate` and `plan`; a human runs `apply`. A malicious pull request cannot
create, change or delete infrastructure.

## Security

| Protection | How |
|---|---|
| Encryption at rest | SSE-S3 (AES256) on the state bucket |
| Encryption in transit | Bucket policy denies `aws:SecureTransport = false` |
| No public access | All four public access block settings enabled |
| Recovery | Versioning keeps every previous state file |
| Accidental deletion | `prevent_destroy = true` on the bucket |
| No long-lived CI keys | GitHub OIDC with 1-hour credentials |
| Repo-scoped trust | `sub` condition limits the role to this repo |
| CI can't change infra | `ReadOnlyAccess` + state access only |

## Locking: S3 lockfile vs DynamoDB

Since Terraform 1.10, S3 can lock state by itself (`use_lockfile = true`), and
HashiCorp has deprecated DynamoDB-based locking. The main project uses
`use_lockfile`. The DynamoDB table is kept to demonstrate the older method.

## ⚠️ Local state

This folder's `terraform.tfstate` is stored **locally** and is git-ignored.
Back it up. If it's lost, Terraform forgets it created these resources (they
keep existing in AWS, and you'd have to `terraform import` them).

## Teardown

Destroy the main project first, then this. Because of `prevent_destroy`:

1. Set `prevent_destroy = false` in `backend/main.tf`
2. Empty the bucket, **including all object versions** (S3 console → bucket → Empty)
3. Run:

```bash
terraform destroy
```

This also removes the OIDC provider and CI role, so GitHub Actions will no
longer be able to access the account.
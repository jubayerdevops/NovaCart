# NovaCart — Highly Available 3-Tier Architecture on AWS

Terraform capstone: ALB (public subnets) → Auto Scaling web tier (private
subnets) → RDS MySQL (database subnets), built from reusable modules.
One codebase deploys a cheap `dev` and a resilient `prod`.

> This README grows milestone by milestone. Architecture diagram, variables,
> outputs, cost estimate and teardown are completed in M06.

## Repository layout

```
NovaCart/
├── bootstrap/          # one-time: state bucket + GitHub OIDC role (see bootstrap/README.md)
├── infra/              # main Terraform project (milestones M01–M06)
│   ├── versions.tf  providers.tf  backend.tf
│   ├── main.tf  variables.tf  outputs.tf
│   ├── terraform.tfvars.example
│   ├── scripts/create-modules.sh
│   └── modules/
│       ├── vpc/  security_groups/  alb/
│       ├── app/  rds/  s3/  bastion/
│       └── (each: main.tf, variables.tf, outputs.tf)
├── docs/               # screenshots and diagrams
├── README.md
└── ANSWERS.md          # design review answers
```

Milestones are marked with Git tags `m1` … `m6`.

## Prerequisites

- Terraform >= 1.10, AWS CLI v2, Git
- An IAM user/role with admin rights — **not the root account**
- An AWS CLI profile configured (`aws configure --profile <name>`)

## Quick start (local state)

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars   # set environment, owner, aws_profile
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan
```

## Enabling remote state

State is stored in S3 so the whole team works from one shared, versioned,
encrypted copy, and locking stops two `apply` runs at the same time.

1. **Create the state bucket once** with the bootstrap project:

```bash
   cd bootstrap
   cp terraform.tfvars.example terraform.tfvars
   terraform init && terraform apply
```

   Note the `state_bucket_name` output (`novacart-tfstate-<ACCOUNT_ID>`).

2. **Uncomment the backend block** in `infra/backend.tf` and replace
   `<ACCOUNT_ID>` with your AWS account ID.

3. **Migrate** any existing local state to S3:

```bash
   cd infra
   terraform init -migrate-state
```

Terraform now stores state at
`s3://novacart-tfstate-<ACCOUNT_ID>/terraform-3tier/dev/terraform.tfstate`
and creates a `.tflock` file next to it while an operation runs
(`use_lockfile = true`, Terraform >= 1.10 — no DynamoDB table required).

## Recreating the module layout

```bash
cd infra
bash scripts/create-modules.sh
```

Creates `modules/<name>/{main,variables,outputs}.tf` for all seven modules,
without overwriting existing files.

## Evidence

### M01 — `terraform init` + `terraform validate`

![M01: terraform init and validate](docs/m01-init-validate.png)
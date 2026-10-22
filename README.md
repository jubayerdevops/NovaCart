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

## Enabling remote state

State is stored in S3 so the whole team works from one shared, versioned,
encrypted copy, and locking stops two `apply` runs at the same time.

`infra/backend.tf` uses **partial backend configuration**: only the fixed
settings (`key`, `encrypt`, `use_lockfile`) are in code. The bucket, region
and AWS profile are supplied at `init` time, because backend blocks can't use
variables and these values differ per person / account.

1. **Create the state bucket once** with the bootstrap project:

```bash
   cd bootstrap
   cp terraform.tfvars.example terraform.tfvars
   terraform init && terraform apply
```

   Note the `state_bucket_name` output (`novacart-tfstate-<ACCOUNT_ID>`).

2. **Create your backend config** (git-ignored):

```bash
   cd infra
   cp backend.hcl.example backend.hcl   # set bucket, region, profile
```

3. **Initialise** (migrates any existing local state to S3):

```bash
   terraform init -migrate-state -backend-config=backend.hcl
```

Terraform stores state at
`s3://novacart-tfstate-<ACCOUNT_ID>/terraform-3tier/dev/terraform.tfstate`
and creates a `.tflock` file next to it while an operation runs
(`use_lockfile = true`, Terraform >= 1.10 — no DynamoDB table required).

## Network (M02)

| Tier | AZ a | AZ b | Route table |
|---|---|---|---|
| Public (ALB, NAT, bastion) | 10.0.0.0/24 | 10.0.1.0/24 | `0.0.0.0/0 → Internet Gateway` |
| Private (app servers) | 10.0.10.0/24 | 10.0.11.0/24 | `0.0.0.0/0 → NAT` (1 shared in dev, 1 per AZ in prod) |
| Database (RDS) | 10.0.20.0/24 | 10.0.21.0/24 | local only — no default route |

CIDRs are computed with `cidrsubnet(var.vpc_cidr, 8, n)`, so changing
`vpc_cidr` re-plans every subnet consistently.

### M02 — terraform plan

![M02: terraform plan](docs/m02-plan.png)

### M02 — Network diagram

![M02: network diagram](docs/m02-network-diagram.svg)

## Security groups (M03)

Each tier trusts only the tier directly in front of it. Tier-to-tier rules
reference **security group IDs**, never CIDR ranges.


| Security group | Inbound | Outbound |
|---|---|---|
| `alb-sg` | TCP 80 from `0.0.0.0/0`<br>TCP 443 from `0.0.0.0/0` *(only if `enable_https`)* | TCP 80 → `app-sg` |
| `app-sg` | TCP 80 from `alb-sg`<br>TCP 22 from `bastion-sg` *(only if `enable_bastion`)* | TCP 443 → `0.0.0.0/0` (via NAT: SSM, Secrets Manager, repos)<br>TCP 80 → `0.0.0.0/0` (via NAT: package repos)<br>TCP 3306 → `db-sg` |
| `db-sg` | TCP 3306 from `app-sg` | *none* |
| `bastion-sg` *(optional)* | TCP 22 from `allowed_ssh_cidr` (my IP /32) | TCP 22 → `app-sg` |

All rules are separate `aws_vpc_security_group_ingress_rule` /
`aws_vpc_security_group_egress_rule` resources (no inline rules). Terraform
removes AWS's default allow-all egress, so only the outbound rules above exist.

### M03 — DB security group allows MySQL only from the app SG

![M03: DB SG inbound rules](docs/m03-db-sg-inbound.png)
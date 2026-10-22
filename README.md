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

## App tier — ALB & Auto Scaling (M04)

```
Internet ──HTTP 80──▶ ALB (public subnets, 2 AZs)
                        └─ listener :80 ──▶ target group (health check GET /health → 200)
                                              ├─▶ EC2 nginx (private subnet, AZ a)
                                              └─▶ EC2 nginx (private subnet, AZ b)
                                                   ▲ managed by the Auto Scaling Group
```

| Component | Configuration |
|---|---|
| ALB | Internet-facing, both public subnets, `drop_invalid_header_fields = true` |
| Target group | HTTP 80, health check `/health` every 15 s (healthy 2 / unhealthy 3), deregistration delay 30 s |
| AMI | Latest Amazon Linux 2023 via `data "aws_ami"` (no hard-coded AMI ID) |
| Launch template | `t3.micro` (dev), **IMDSv2 required**, **encrypted gp3 root volume**, **no SSH key** |
| IAM | Instance profile with `AmazonSSMManagedInstanceCore` → shell access via Session Manager |
| User data | `templatefile()` renders `user_data.sh.tftpl`: installs nginx, reads hostname / AZ / instance ID from IMDSv2, serves them with the environment name |
| Auto Scaling Group | Private subnets in both AZs, `health_check_type = "ELB"`, grace 180 s, min/desired/max from variables (dev: 1 / 2 / 2) |
| Scaling policy | Target tracking: average CPU **50 %** |
| Instance refresh | Rolling, `min_healthy_percentage = 50` — triggered when the launch template changes |

Open the app: `terraform output alb_dns_name` → `http://<alb_dns_name>`

### Chaos drill — self-healing

1. Started a loop requesting the ALB every 2 s.
2. At `<time>` terminated `i-0519bc6c1d31b64be` (ap-southeast-1b).
3. The ALB stopped routing to it immediately; every request was served by
   `i-0d1897a0fddae63e7` (1a) — **no downtime**.
4. At `<time>` the ASG detected capacity below desired (1 of 2) and launched
   `<new instance id>` in ap-southeast-1b.
5. At `<time>` it passed health checks; the target group was back to 2 healthy
   targets. Total recovery: about `<n>` minutes, with no manual action.

### Flash-sale drill — scaling out

1. Set the ASG to 1 instance (`desired = 1`).
2. Via Session Manager ran `stress-ng --cpu 2 --timeout 600` on the instance.
3. Average CPU rose above the 50 % target; at `<time>` the target-tracking
   alarm fired and the ASG launched a second instance (`<instance id>`).
4. After the load stopped, CPU fell and the ASG scaled back in to 1 instance
   at `<time>`.


### M04 — Web page via the ALB (two instances, two AZs)

![M04: served from AZ a](docs/m04-web-az-a.png)

![M04: served from AZ b](docs/m04-web-az-b.png)

### M04 — Session Manager shell (no SSH keys)

![M04: SSM session](docs/m04-ssm-session.png)

### M04 — Chaos drill: ASG replaces a terminated instance

![M04: ASG activity](docs/m04-chaos-activity.png)

![M04: targets healthy again](docs/m04-chaos-healthy.png)

### M04 — Flash-sale drill: ASG scales out on CPU

![M04: CPU alarm](docs/m04-flash-cpu.png)

![M04: scale-out activity](docs/m04-flash-activity.png)
# Design Review Answers

## Milestone 01 — Never Again by Hand

### 1. Why is remote state with locking important when working in a team?

The state file is Terraform's record of what exists in AWS. If it lives on
one laptop, nobody else can safely change the infrastructure: Sam would plan
against an empty or outdated state and try to recreate — or destroy —
resources that already exist.

Storing it in S3 gives the team one shared source of truth. Versioning lets
us roll back a corrupted state, encryption protects any sensitive values it
contains, and the bucket policy forces HTTPS. Locking guarantees that only
one operation can change that shared state at a time.

### 2. What happens if you and Sam run `terraform apply` at the same time without locking?

Both runs read the same starting state and each builds its own plan. Both
then make real API calls to AWS — possibly creating duplicate resources, or
one run changing or deleting what the other just created. Finally each writes
its own version of the state, and **the last one to write wins**: resources
created by the other run still exist in AWS (and still cost money) but are
missing from the state, so Terraform no longer knows about them. The state
can also be left corrupted.

With locking (`use_lockfile = true`), the first run creates a `.tflock` file
in S3. The second run fails immediately with *"Error acquiring the state
lock"* and must wait until the first one finishes.

## Milestone 02 — Lay the Roads

### 1. Why do the app servers live in private subnets yet still reach the internet?

Private subnets have no route to the Internet Gateway and their instances
have no public IP, so nothing on the internet can open a connection *to*
them — the only way in is through the ALB. They still need outbound access
for package installs, OS updates and AWS APIs (SSM, Secrets Manager). Their
route table sends `0.0.0.0/0` to a NAT Gateway in a public subnet, which
forwards their requests using its own Elastic IP and lets only the replies
back in. Outbound works; inbound from the internet is impossible.

### 2. What is the trade-off between a single NAT Gateway and one per AZ?

**Single NAT (dev):** half the cost — each NAT costs about USD 0.06/hour
plus data processing, whether used or not. But it lives in one AZ: if that
AZ fails, servers in the *other* AZ lose outbound internet even though they
are healthy, and traffic crossing AZs to reach the NAT adds data-transfer
charges.

**One NAT per AZ (prod):** each private subnet routes through the NAT in its
own AZ, so an AZ outage only affects that AZ — true high availability and no
cross-AZ NAT traffic — at the cost of paying for one NAT and Elastic IP per AZ.

In this project `single_nat_gateway = true` in dev and `false` in prod.

## Milestone 03 — Locks on Every Door

### 1. Why is referencing a security group ID safer than allowing a CIDR range?

A CIDR rule trusts an **address range**, not a role. `10.0.0.0/16` would let
*anything* in the VPC reach the database — the ALB, the bastion, NAT, any
future server — and app servers in an Auto Scaling Group get new IPs every
time they're replaced, so a tight CIDR would break.

A security-group reference trusts **membership**: only network interfaces
that have the app SG attached can reach port 3306. New instances launched by
the ASG automatically get the SG and are allowed; anything else in the same
subnet is not. The rule follows the role, not the IP, and stays least-privilege
as the fleet scales.

### 2. If the ALB is compromised, what can an attacker reach directly?

Only the app servers, on port 80. The ALB SG's only outbound rule is
TCP 80 → `app-sg`, so from the ALB an attacker:

- **can** send HTTP requests to the app instances (the same as normal users)
- **cannot** reach the database — `db-sg` accepts 3306 only from `app-sg`,
  and the ALB has no egress on 3306
- **cannot** SSH anywhere — no port 22 egress, and the app tier accepts 22
  only from the bastion SG
- **cannot** reach the internet or other services — no other egress rules

To get to the data they would first have to compromise an app server too.
Each layer has to be broken separately — that's defence in depth.

## Milestone 04 — Survive the Friday Sale

### 1. What attack does IMDSv2 protect against?

**Server-Side Request Forgery (SSRF).** Every EC2 instance can read its own
metadata — including the temporary AWS credentials of its IAM role — from
`http://169.254.169.254`. With IMDSv1 a plain `GET` was enough, so if an
attacker could trick the web app into fetching a URL of their choice (e.g.
an image-preview or webhook feature), they could make it request
`/latest/meta-data/iam/security-credentials/<role>` and steal the keys.
This is how the 2019 Capital One breach happened.

IMDSv2 (`http_tokens = "required"`) first requires a `PUT` request to get a
session token, which then has to be sent as a header on every metadata
request. Typical SSRF bugs can only make simple `GET` requests and can't set
custom headers, so they can no longer reach the credentials. With
`http_put_response_hop_limit = 1`, the token also can't leave the instance
(e.g. through a proxy or container).

### 2. What happens to running instances when you change the user data and apply with instance refresh enabled?

Nothing happens to them directly — user data only runs on **first boot**, so
existing instances never re-run it. Instead:

1. Terraform creates a **new version** of the launch template, and the ASG
   points at that new version.
2. Because the ASG has an `instance_refresh` block, Terraform starts a
   **rolling instance refresh**.
3. The ASG replaces instances in batches, keeping at least
   `min_healthy_percentage` (50 %) of capacity healthy: it terminates an old
   instance, launches a new one from the new template version (which runs the
   new user data), waits for it to pass health checks and the
   `instance_warmup` period, then moves on to the next.
4. The ALB keeps routing only to healthy targets throughout, so the site
   stays up — a zero-downtime rolling deployment.

Without instance refresh, the old instances would keep running the old
configuration until they happened to be replaced.

## Milestone 05 — Guard the Crown Jewels

### 1. Why is it better to let RDS manage the password in Secrets Manager than to pass it as a Terraform variable?

A password passed as a variable — even `sensitive = true` — is stored in
**plain text in the Terraform state file**, and often also in tfvars files,
CI logs or shell history. Anyone who can read the state bucket can read it.

With `manage_master_user_password = true`, RDS generates the password itself
and stores it in Secrets Manager. Terraform only ever sees the secret's ARN.
The password is encrypted with KMS, access is controlled by IAM (only the app
role can read this one secret), every read is logged in CloudTrail, and RDS
can rotate it automatically without any code change or redeploy.

### 2. What does Multi-AZ protect against, and what does it NOT protect against?

**Protects against:** failure of the primary DB instance or its whole
Availability Zone (hardware, power, network) and planned maintenance. RDS
keeps a synchronous standby in a second AZ and fails over automatically in
about 1–2 minutes; the endpoint DNS name stays the same.

**Does NOT protect against:**
- **Bad data** — accidental `DELETE`/`DROP`, application bugs or corruption
  are replicated to the standby instantly. You need backups / point-in-time
  restore for that.
- **Region-wide outages** — both copies are in the same region (needs
  cross-region read replicas or snapshot copies).
- **Scaling reads** — the standby can't serve traffic (read replicas do).
- **Security incidents** — stolen credentials or a compromised app reach both.

## Milestone 06 — Launch Day

### 1. Workspaces vs separate state keys/directories — which would you use for real production and why?

**Separate state keys (or directories), not workspaces.** With workspaces,
the active environment is invisible state on the engineer's machine
(`terraform workspace select`); one forgotten switch and a dev change is
applied to prod. All workspaces also share the same backend and credentials,
so you can't give prod stricter access.

Separate keys make the environment explicit in every command
(`-backend-config=prod.backend.hcl -var-file=prod.tfvars`), visible in CI
logs and code review, and each state path can have its own IAM policy (CI
can plan prod, only a release role can apply it). For real production I'd go
further: separate AWS accounts per environment, each with its own state
bucket. HashiCorp itself recommends against workspaces for environments that
need different credentials or access controls.

### 2. Which three resources drive most of the cost, and how would you reduce them?

1. **NAT Gateways** (~$47/month each, plus $0.059/GB processed — two in prod).
   Reduce: one shared NAT in dev; add free **S3 / DynamoDB gateway VPC
   endpoints** and interface endpoints for SSM / Secrets Manager so that
   traffic skips the NAT; in non-prod, destroy outside working hours.
2. **RDS** (Multi-AZ doubles the price; extended support for old engine
   versions adds even more). Reduce: Multi-AZ only in prod, smallest
   instance in dev, current engine version (8.4 — avoids 8.0 extended
   support), Reserved Instances for prod, stop/destroy dev databases at night.
3. **EC2 app fleet + ALB.** Reduce: right-size with CloudWatch data,
   Graviton (`t4g`, ~20 % cheaper), Savings Plans for the prod baseline, Spot
   for extra scale-out capacity, scheduled scaling to min outside business
   hours, and the target-tracking policy already scales in when idle.
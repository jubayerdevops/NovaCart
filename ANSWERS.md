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
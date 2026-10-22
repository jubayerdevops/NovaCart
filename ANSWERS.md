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
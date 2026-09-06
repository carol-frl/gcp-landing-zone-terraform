# 000 — Bootstrap project and Terraform state

## Context

The landing zone is built from a clean organization. Before any folder,
project, or policy exists, Terraform needs somewhere to keep state and CI needs
an identity to run as. Neither can be created by the pipeline that depends on
them, so this first root is applied by a human with their own credentials
against local state, then migrated.

This decision fixes two things that are expensive to change later: which
project owns the state bucket, and what that bucket's location is.

## Options considered

**A dedicated bootstrap project.** One project holds the state bucket, the CI
service account, and the Workload Identity pool. Nothing else is ever deployed
into it. Its only inbound dependency is the org node.

**The state bucket in an existing project.** Fewer resources to create and one
less project to pay attention to. Couples the state of every environment to a
project that has other reasons to exist, other owners, and its own lifecycle.
An IAM change made for that project's primary purpose can widen access to
state as a side effect.

**HCP Terraform (or another managed backend).** Gets run history, native RBAC
over who can apply what, and policy-as-code without building it. Costs money at
team size, moves the audit trail outside GCP where the rest of the org's
logging lives, and makes the portfolio artifact depend on a second vendor's
free tier to be reproducible.

## Decision

A dedicated bootstrap project with a versioned GCS bucket for state.

The deciding factor is blast radius, not convenience. The state bucket is the
one resource whose compromise compromises everything else — it holds the
current picture of the whole org, in plaintext. Giving it a project with no
other purpose means its IAM policy has no other reason to change, so any change
to that policy is by definition about state access and is visible as such in
review. That property is lost the moment the bucket shares a project with
something people actually work in.

GCS over HCP Terraform because the audit trail stays in Cloud Logging alongside
every other action against this org, and because the repo has to be runnable by
a reviewer with nothing but a GCP account.

## Consequences

**One step is permanently un-automated.** The bootstrap root applies with a
human's credentials against local state before the backend exists. It cannot be
run by CI, because CI's identity is one of the things it creates. If the
bootstrap project is ever lost, recovery is manual and begins with someone
holding org-level permissions at a terminal. This is inherent to the pattern
rather than a shortcoming of this implementation, but it means the disaster
recovery runbook has a hand-written first page.

**The CI service account is the highest-privilege principal in the org.** It
holds `resourcemanager.folderAdmin`, `resourcemanager.projectCreator`,
`orgpolicy.policyAdmin` and `compute.xpnAdmin` at the organization node,
because the resources it manages do not exist yet and cannot be targeted more
narrowly. Anyone who can merge to `main` can reach all four. Two controls
narrow this and neither eliminates it: the Workload Identity provider's
attribute condition pins federation to a single repository, so a valid GitHub
OIDC token from anywhere else is refused; and apply runs behind a required
environment approval. The residual risk is a malicious or mistaken merge by
someone already trusted, which is accepted here and would not be accepted in an
org with real workloads — that org should split CI into per-scope identities.

**Read access to the bucket is read access to every secret Terraform manages.**
Terraform state stores resource attributes in plaintext, including generated
passwords and keys. `roles/storage.objectAdmin` on this bucket is therefore a
privileged grant regardless of how routine it looks, and membership of the
Terraform admin group must be reviewed as a security boundary, not as
convenience access. Bucket-level IAM is used rather than project-level so that
this grant is at least legible in one place.

**The bucket's location is permanent.** Changing region later means copying
objects and re-pointing every backend block by hand, with all applies frozen in
between.

**Ten archived versions is a guess.** It is enough to walk back a bad apply and
bounded so the bucket cannot grow without limit, but it is not a retention
policy. An org with compliance requirements on infrastructure change history
needs the audit trail in Cloud Logging, not in object versions.

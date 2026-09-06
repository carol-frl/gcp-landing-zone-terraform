# 002 — Network Connectivity Center hub above Shared VPC

## Context

Each environment has its own Shared VPC: `shared-prd` and `shared-nonprd`, in
separate host projects, with teams delegated subnets inside them. Nothing
connects those two networks, and nothing connects either to on-premises.

Two requirements arrive together. Some traffic legitimately crosses the
environment boundary — a non-production service reading a production replica,
shared tooling, CI runners that need to reach both. And hybrid connectivity is
coming, which means Interconnect attachments that must reach workloads in both
environments rather than terminating in one.

The question is what sits above the two Shared VPCs. The question is *not*
whether teams keep getting delegated subnets — that part works and is not
being reopened.

## Options considered

**Leave them disconnected.** Cheapest and safest. Every cross-environment need
is solved through a public endpoint with its own authentication, and hybrid
connectivity is duplicated per environment. Honest option, and it is what the
repository does today.

**VPC peering between the two networks.** One peering, free, immediate. Peering
is non-transitive, which is the disqualifier rather than an inconvenience: an
Interconnect attachment landing in the production VPC would be reachable from
production only, so hybrid connectivity would have to be built twice and kept
in step. Adding a third environment turns one peering into three.

**NCC hub with the two Shared VPCs as VPC spokes.** A hub in its own project;
each environment's network attaches as a spoke; Interconnect and VPN spokes
attach to the same hub and are reachable from both environments transitively.
Shared VPC continues to own subnet delegation underneath.

**NCC hub with a VPC per team, replacing Shared VPC.** Full hub-and-spoke.
Teams own their own networks outright — real autonomy, no host project
bottleneck. Costs a spoke-hour per team per environment, and gives up
subnet-level IAM delegation, central IP allocation, and the project factory's
ability to hand a team a network without the team owning one.

## Decision

An NCC hub in a dedicated network project, with each environment's Shared VPC
attached as a VPC spoke. Shared VPC is retained beneath it for team subnet
delegation.

Transitivity is what decides it. Peering would work for exactly one
cross-environment link and then fail the moment hybrid connectivity arrives,
because an Interconnect attachment reachable from one environment only is not
hybrid connectivity — it is a second thing to build. NCC makes on-premises
reachable from both environments through one set of attachments, which is the
whole reason the hybrid design in `docs/architecture.md` buys four attachments
rather than eight.

Per-team VPC spokes were rejected on cost shape rather than on architecture.
The full hub-and-spoke model is defensible and would give teams more autonomy
than they have today. But its recurring cost scales with team count, while this
design's scales with environment count — two spokes whether there are two teams
or twenty. Adding a team stays free because it adds a subnet inside an existing
spoke's VPC, not a spoke. Given that no team has asked to own a network, paying
per team for autonomy nobody requested is the wrong trade.

## Consequences

**This is the first recurring cost in the repository.** NCC bills spoke-hours
for every hour a spoke exists, regardless of whether any traffic crosses it.
The free allowance covers up to three VPN spokes and three Interconnect spokes
and explicitly does not cover VPC spokes, so both environment spokes bill from
creation. Everything else in this landing zone — folders, org policy, IAM,
Shared VPC, the project factory — is free at rest. That property ends here, and
it ends permanently, because a transit fabric that is switched off is not a
transit fabric. `vpc_spokes` defaults to empty so that turning it on is a
reviewable diff rather than a consequence of applying a root, but that is a
speed bump, not a mitigation.

**Connecting production to non-production is a security decision, not a
topology one.** Before this, a compromised non-production workload had no
network path to production; the isolation was structural and free. After this,
the isolation is a routing configuration — `include_export_ranges` on each
spoke — that someone can widen in a one-line diff. That control is weaker than
the absence of a route, and it now needs to be reviewed as a security boundary
rather than as network plumbing. The alternative was accepting that CI and
shared tooling reach both environments over the public internet, which trades
a routing risk for an authentication one.

**The hub is a new failure domain and a new bottleneck.** It is a single
resource that both environments depend on for transit, owned by neither, in a
project that needs an owner. A bad export-range change affects both
environments at once. This is the same criticism ADR 001 accepted for the host
project, arriving one level higher.

**Ordering across state files is now real.** The hub root's spokes reference
networks created by the two environment roots, so it applies third and its
`terraform.tfvars` carries values copied from their outputs. There is no
dependency graph across roots to enforce that — it is documented in the README
and nothing will stop someone applying them out of order except an error
message.

**NCC is a younger product than Shared VPC.** Fewer people have debugged it
under pressure, the failure modes are less documented publicly, and the
operational corpus is thinner. That is a real cost paid in incident response
time, not in dollars, and it is the argument the "leave them disconnected"
option would have made most strongly.

**Nothing here has been applied.** The topology is written and validated; its
routing behaviour is not proven. Export range interactions between spokes in
particular are the kind of thing that reads correctly and behaves differently.

# 001 — Folder hierarchy

## Context

Two environments, production and non-production, and a small number of
delivery teams — two at the time of writing, with the structure expected to
hold to roughly ten. Every team needs isolated projects per environment,
central platform ownership of guardrails, and enough self-service that adding a
team is not a platform-team project.

Folder position is not cosmetic in GCP. It determines what org policy a
resource inherits and what a single IAM binding can reach. Those two forces
want opposite shapes, so the hierarchy is a choice between them rather than a
naming convention.

## Options considered

**Environment above team** — `org / production / payments`. Org policy is
applied once per environment and inherited by every team below it. IAM for a
team is split across environment subtrees.

**Team above environment** — `org / payments / production`. A team lead gets
one binding at their folder covering everything the team owns. Environment
guardrails must be applied once per team, at every team's environment
sub-folder.

**Flat** — every project directly under the org, distinguished by naming
convention and labels. Nothing inherits usefully; every control is applied
per project. Included because it is what most orgs actually have, and it is
survivable at five projects.

## Decision

Environment above team.

Org policy is the strongest control available in this org and it only flows
downward. The constraints that matter most — denying external IPs, restricting
resource locations, blocking service account key creation — differ by
environment and not by team. Production wants all of them enforced; a sandbox
needs them loosened or nobody can experiment. Putting environment on top means
each of those policy sets is expressed exactly once, at one node, and every
team created afterwards inherits it by construction.

Team above environment inverts that. The production guardrail set would be
applied once per team folder, N times, and a team folder created without it
would be a production environment with no policy on it and nothing structural
to reveal the gap. That is a failure mode that gets worse as the org grows,
and it fails silently.

Flat was rejected because it makes both problems permanent.

## Consequences

**Per-team IAM delegation is worse, deliberately.** A team lead cannot be
granted admin over everything their team owns in one binding; their scope is
split across `production/payments` and `non-production/payments`, and the
bindings must be kept in step. Team-above-environment would have given this for
free. The trade was made because a duplicated IAM binding is an annoyance that
automation absorbs, while a missed org policy on a production folder is a
security incident. The project factory generating those bindings from a single
team entry is what makes the annoyance affordable — this hierarchy would be
painful to run by hand, and that dependency is real.

**Folder count is the product of environments and teams.** Adding a third
environment does not add one folder, it adds one per team. At ten teams that is
ten folders and ten sets of bindings from a single decision, all generated, but
all of it plan output someone has to read.

**Team-wide exceptions have no single place to live.** A team that legitimately
needs a constraint relaxed must have it relaxed once per environment, or pushed
down to individual projects. There is no node meaning "everything this team
owns" to attach an exception to. Exceptions therefore need an explicit review
path rather than a convenient folder.

**Cost attribution cannot use folder position.** A team's spend is split across
environment subtrees, so answering "what does the payments team cost" requires
labels applied consistently by the project factory and billing export queried
by label. Under team-above-environment that question would have been a folder
subtotal in the console.

**Reorganisations are expensive.** If teams merge or split, folders move in
every environment at once, and project parents change with them. The hierarchy
assumes team boundaries are more stable than environment boundaries, which is
true in most orgs and worth stating as an assumption rather than a fact.

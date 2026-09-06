# modules/ncc-hub

A Network Connectivity Center hub, plus VPC spokes for the environment Shared
VPCs. This is the transit layer — it sits *above* Shared VPC, not instead of
it. Teams still get delegated subnets from `modules/shared-vpc`.

Reasoning in [ADR 002](../../docs/decisions/002-ncc-hub-topology.md).

## Usage

```hcl
module "hub" {
  source = "../../modules/ncc-hub"

  project_id = "acme-net-hub"
  hub_name   = "lz-hub"

  vpc_spokes = {
    prd = {
      network               = "projects/acme-host-prd/global/networks/shared-prd"
      include_export_ranges = ["10.0.0.0/12"]
    }
    nonprd = {
      network               = "projects/acme-host-nonprd/global/networks/shared-nonprd"
      include_export_ranges = ["10.1.0.0/12"]
    }
  }
}
```

## Cost — read before enabling

**NCC bills per spoke-hour for as long as a spoke exists, regardless of whether
any traffic crosses it.** The free allowance covers up to three VPN spokes and
three Cloud Interconnect spokes; it does **not** cover VPC spokes. Both
environment spokes bill from creation.

`vpc_spokes` defaults to `{}` so the hub can be created without billing
anything, making the switch-on a reviewable diff. That is a staging
convenience, not a mitigation — a transit fabric with no spokes carries nothing.

This is the only permanent cost in the landing zone. Verify current rates at
[cloud.google.com/network-connectivity/pricing](https://cloud.google.com/network-connectivity/pricing).

Cost scales with **environment** count, not team count: adding a team adds a
subnet inside an existing spoke's VPC, not a spoke. That is the whole reason
Shared VPC was kept underneath rather than giving each team its own VPC.

## Export ranges are a security boundary

`include_export_ranges` decides what a spoke advertises to the rest of the hub.
Left unset, a spoke exports everything, which means every subnet created in
that VPC afterwards becomes reachable from every other spoke the moment it
exists — a routing change nobody reviewed.

Before the hub, production and non-production had no path to each other and the
isolation was structural. After it, the isolation is this field. Review changes
to it the way you would review a firewall rule, not a network config.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `project_id` | string | — | Project holding the hub and spokes. Separate from the host projects on purpose. |
| `hub_name` | string | `lz-hub` | Hub name; prefixes every spoke. |
| `vpc_spokes` | map(object) | `{}` | Keyed by short name. Each has `network` (self link) and optional `include_export_ranges` / `exclude_export_ranges`. |

## Outputs

| Name | Description |
|---|---|
| `hub_id` | Hub resource ID. Interconnect and VPN spokes attach here. |
| `hub_name` | Hub name. |
| `vpc_spoke_names` | Attached VPC spokes. Each one is billing. |

## What this does not cover

No Interconnect or VPN spokes — those need physical attachments and are
designed in [docs/architecture.md](../../docs/architecture.md). No hybrid
inspection or gateway spokes. No route table policy beyond export ranges.

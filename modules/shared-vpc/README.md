# modules/shared-vpc

Creates the Shared VPC host project, the network, one subnet per team per
region with GKE secondary ranges, a hierarchical firewall policy attached at
the folder, and optionally Cloud NAT.

Service project attachment and subnet IAM are **not** here. Those are per-team
and belong to the project factory (Weekend 4), which is the only component that
knows a team exists.

## Usage

```hcl
module "network" {
  source = "../../modules/shared-vpc"

  folder          = "folders/123456789012"
  billing_account = "XXXXXX-XXXXXX-XXXXXX"
  host_project_id = "acme-lz-host-prod"
  network_name    = "shared-prod"
  regions         = ["europe-west4"]

  subnets = {
    "payments/europe-west4" = {
      region   = "europe-west4"
      primary  = "10.0.0.0/20"
      pods     = "10.64.0.0/16"
      services = "10.80.0.0/20"
    }
  }
}
```

## Why CIDRs are explicit and not calculated

The obvious implementation generates ranges with `cidrsubnet()` over a supernet
indexed by team position. It is shorter and it is a trap: adding a team to the
middle of the list renumbers every subnet after it, and Terraform reads a
changed `ip_cidr_range` as destroy-and-recreate. That is a live network outage
produced by an alphabetical insert.

Explicit CIDRs cost the caller a few lines per subnet and make IP allocation a
reviewable decision with a diff, which is what it should be. The trade is real:
nothing stops someone allocating overlapping ranges, so allocation has to be
tracked somewhere a human reads.

## GKE secondary ranges are allocated up front

Pods and services ranges are created with every subnet whether or not a cluster
exists. Secondary ranges cannot be added to a subnet already carrying traffic
without disruption, so allocating them lazily means the first GKE cluster in a
team requires a maintenance window in the host project.

The cost is IP space reserved against clusters that may never be built. At a
`/16` per team per region that space is not free, and it is the main reason
this design would need revisiting well before fifty teams.

## Firewall model

The hierarchical policy is evaluated before any VPC firewall rule in any
project below it, so a deny here cannot be overridden by a team. That makes it
powerful and makes an over-broad rule an org-wide outage.

| Priority | Action | What |
|---|---|---|
| 1000 | allow | SSH/RDP from the IAP range only |
| 1100 | allow | Google load balancer health check ranges |
| 2000 | deny | SSH, RDP, SMB/NetBIOS from `0.0.0.0/0` |
| 65000 | goto_next | Everything else, delegated to project VPC firewall rules |

The baseline denies named management ports rather than denying everything,
because a default-deny at this level would require the allow list to be
complete before a single workload could serve traffic. Platform owns the
ports that get a VM compromised; teams own their own application rules.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `folder` | string | — | `folders/NNN` — host project parent and firewall policy attachment point. |
| `billing_account` | string | — | Billing account for the host project. |
| `host_project_id` | string | — | Globally unique project ID. |
| `network_name` | string | `shared` | Network name; prefixes the policy and NAT gateways. |
| `regions` | list(string) | — | Regions to create NAT in when enabled. |
| `subnets` | map(object) | — | Keyed `"team/region"` with `region`, `primary`, `pods`, `services`. |
| `enable_nat` | bool | `false` | Provision Cloud Router + Cloud NAT. Costs money while on. |
| `enable_flow_logs` | bool | `false` | VPC flow logs on every subnet. Billed per GB generated. |

## Outputs

| Name | Description |
|---|---|
| `host_project_id` | Host project; service projects attach to this. |
| `network_id` | Network self link. |
| `subnet_ids` | Subnet self links keyed by `"team/region"`. |
| `subnet_self_links` | `name`/`region` pairs keyed the same way. |
| `firewall_policy_id` | The hierarchical policy. |
| `nat_enabled` | Whether egress to the internet currently exists. |

## Cost

With the defaults, close to nothing: a project, a network, subnets and
firewall policy rules are not billed. Two switches turn that around.

**`enable_nat`** bills on four axes at once — an hourly rate per VM using the
gateway (capped at 32 VMs), per-GiB data processing, an hourly charge per
external IP the gateway holds, and ordinary internet egress on top. An idle
gateway is on the order of tens of dollars a month before any traffic passes
through it, per region. Rates change; check
[cloud.google.com/nat/pricing](https://cloud.google.com/nat/pricing) rather
than trusting this paragraph.

**`enable_flow_logs`** bills per GB of logs generated, which scales with
traffic rather than with instance count. It is the easier of the two to be
surprised by.

Both default to false. The rest of the landing zone plans and applies without
either, so the demo costs nothing to stand up.

## What this does not cover

No Interconnect or VPN — see [docs/architecture.md](../../docs/architecture.md)
for the hybrid connectivity design and why it is documented rather than built.
No Private Service Connect endpoints, no Cloud DNS zones, no egress firewall
rules beyond the implicit allow.

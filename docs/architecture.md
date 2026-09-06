# Architecture

Design notes for the parts of this landing zone that are deliberately not
provisioned. Everything described here has standing cost, a physical
dependency, or both, so it is documented and costed rather than built.

## Hybrid connectivity

The network module builds a Shared VPC with no path to on-premises. In a real
deployment that path is Dedicated Interconnect, and its design is the part
worth getting right before anyone orders a circuit.

### Redundant attachments

A single VLAN attachment has no SLA. Google's availability commitments are
earned by topology, not by product choice:

| Topology | Attachments | Placement | SLA |
|---|---|---|---|
| Non-redundant | 1 | One edge availability domain | None |
| Redundant | 2 | Two edge availability domains in one metro | 99.9% |
| High availability | 4 | Two attachments in each of two metros | 99.99% |

An edge availability domain is a maintenance boundary: Google guarantees it
will not take both domains in a metro down at once. Two attachments in the
*same* domain is the failure mode that looks redundant on a diagram and is not,
because one scheduled maintenance window drops both.

Each attachment terminates on its own Cloud Router. Sharing a Cloud Router
between attachments reintroduces the single point of failure that the second
attachment was bought to remove.

Attachments attach to the NCC hub as Interconnect spokes rather than landing
directly in one environment's VPC. That is what makes four attachments serve
both environments instead of four serving one; see "The transit hub" below.

The 99.99% topology also requires the two metros to be geographically distinct
and the on-premises side to be genuinely dual-homed. Buying four attachments
into one building's single router yields the price of 99.99% and the
availability of 99.9%.

### Routing

BGP over each attachment, with Cloud Router advertising the VPC's subnet
ranges and learning on-premises prefixes.

Route selection is a choice, not a default:

- **Active/active** — equal MED on all sessions, traffic ECMPs across
  attachments. Uses the capacity that has been paid for. Makes per-flow
  troubleshooting harder because the return path is not deterministic.
- **Active/passive** — MED prefers one metro, the other takes over on failure.
  Predictable and easier to reason about during an incident. Half the purchased
  capacity is idle most of the time.

This design assumes active/active, because at four attachments the idle cost of
active/passive is the dominant line item and the troubleshooting difficulty is
absorbed by flow logs rather than by design.

Custom route advertisement is set explicitly rather than advertising all
subnets, so that adding a subnet in GCP is not silently a change to what
on-premises can reach. The VPC's `routing_mode` is `GLOBAL`, which means a
Cloud Router in one region propagates learned routes to every region — that is
what makes a two-metro attachment reach workloads everywhere, and it is also
what makes a bad advertisement global. Regional dynamic routing is the
containment option if the route table ever becomes something nobody can read.

### Cost

Dedicated Interconnect bills a monthly port charge per 10 Gbps or 100 Gbps
circuit, plus a per-hour charge per VLAN attachment, plus egress at discounted
Interconnect rates. The 99.99% topology multiplies the port charge by four
before a single byte moves, and cross-connect fees are paid to the colocation
facility rather than to Google, so they do not appear on the GCP bill at all.

This lands in the thousands of dollars a month. Partner Interconnect is the
alternative at lower bandwidth and lower commitment; HA VPN over the internet
is the alternative again below that, at roughly the cost of two tunnels and
without the latency guarantee. Verify current rates against
[cloud.google.com/network-connectivity/docs/interconnect/pricing](https://cloud.google.com/network-connectivity/docs/interconnect/pricing)
before quoting any of this.

That cost is the entire reason this is a document and not Terraform.

## Why Shared VPC rather than VPC peering

Both give teams isolated projects with private connectivity. They differ in who
owns the network.

**VPC peering** gives each team its own VPC, peered with the others. Teams own
their firewall rules and their address space, and the platform team is not in
the path of every change. The constraints are structural: peering is
non-transitive, so full connectivity between N VPCs needs N(N-1)/2 peerings —
ten teams is forty-five peerings to create and reason about. Peered ranges
cannot overlap, so address allocation ends up centrally coordinated anyway,
just without a system for it. And there is a hard limit on peerings per
network, which the growth path runs into rather than grows out of.

**Shared VPC** puts one network in a host project and attaches team projects as
service projects. IP allocation, routing, and the firewall baseline are owned
centrally; teams are delegated their own subnets through IAM and can build
freely inside them.

At this team count Shared VPC is the clear choice. The peering mesh's cost is
combinatorial and its address coordination is manual, while Shared VPC's cost
is a central team that has to be responsive — which is a staffing problem, and
a smaller one at this size than a forty-five-edge mesh.

What is given up is real and should be said plainly. The host project becomes a
change bottleneck: every subnet, every route, every baseline firewall change
goes through one team and one repository. A team that needs an unusual network
topology cannot simply build it. There is a quota ceiling on service projects
per host project that a very large org reaches. And the host project is a
single failure domain — a bad apply against the network affects every team at
once, which is precisely why the hierarchical firewall policy denies rather
than allows by default and why NAT is opt-in.

The decision flips when teams need genuinely independent networking, when the
org spans multiple GCP organizations, or when the central team stops being able
to turn requests around fast enough that teams route around them. At that point
the answer is a VPC per team attached to the transit hub described below, not a
peering mesh — which is a change in who owns the network, not a change in how
the pieces connect.

## The transit hub

Shared VPC answers "how does a team get a network". It does not answer "how do
two environments reach each other" or "where does on-premises land", because a
Shared VPC is a single network and there are two of them.

A Network Connectivity Center hub sits above both, in its own project, with
`shared-prd` and `shared-nonprd` attached as VPC spokes. Interconnect and VPN
spokes attach to the same hub. The property that matters is transitivity: a
spoke can reach other spokes through the hub, so one set of Interconnect
attachments serves both environments. VPC peering cannot do this — peering is
non-transitive, so an attachment landing in the production VPC would be
reachable from production only, and the four-attachment topology above would
have to be bought twice.

The hub is deliberately *above* Shared VPC rather than instead of it. The
alternative — a VPC per team, each its own spoke — gives teams real network
autonomy and is a defensible design. It also makes the recurring cost scale
with team count rather than environment count, and gives up subnet-level IAM
delegation entirely. Two spokes serve two teams or twenty; that is the trade.
See [ADR 002](decisions/002-ncc-hub-topology.md).

### What the hub costs

NCC bills per spoke-hour for as long as a spoke exists, whether or not traffic
crosses it. The free allowance covers up to three VPN spokes and three Cloud
Interconnect spokes and does not cover VPC spokes, so both environment spokes
bill from the moment they are created. Verify current rates at
[cloud.google.com/network-connectivity/pricing](https://cloud.google.com/network-connectivity/pricing).

This is the only permanent cost in the landing zone. Everything else is either
free at rest or switchable. `vpc_spokes` defaults to empty so that the hub can
exist without billing, but that is a staging convenience: a transit fabric with
no spokes is not carrying anything.

### What the hub changes about isolation

Before the hub, production and non-production had no network path to each
other, and that isolation was structural — there was no route to remove. After
it, the isolation is `include_export_ranges` on each spoke: a configuration
that can be widened in a one-line diff.

That is a genuinely weaker control, and it means export ranges are a security
boundary rather than network plumbing. They should be reviewed as such. The
argument for accepting it is that the alternative — CI and shared tooling
reaching both environments over public endpoints — trades a routing risk for an
authentication one, and authentication is the thing more often got wrong.

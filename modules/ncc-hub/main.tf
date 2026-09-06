# Network Connectivity Center hub.
#
# The hub is the transit fabric between the environment Shared VPCs and,
# eventually, on-premises via Interconnect or VPN spokes. Team subnet
# delegation stays in Shared VPC — this sits above that, not instead of it.
#
# COST: spoke-hours are billed for every hour a spoke is provisioned,
# regardless of how much data crosses it. The free allowance covers up to
# three VPN spokes and three Cloud Interconnect spokes; VPC spokes are NOT
# covered and bill from creation. Verify current rates at
# https://cloud.google.com/network-connectivity/pricing
#
# vpc_spokes therefore defaults to empty: applying this root creates the hub
# and attaches nothing, so turning on the billed part is a reviewable diff.

resource "google_network_connectivity_hub" "hub" {
  name        = var.hub_name
  project     = var.project_id
  description = "Transit hub for environment Shared VPCs and hybrid connectivity."

  labels = {
    managed_by = "terraform"
  }
}

resource "google_network_connectivity_spoke" "vpc" {
  for_each = var.vpc_spokes

  name    = "${var.hub_name}-${each.key}"
  project = var.project_id

  # VPC spokes are global. Regional locations are for VPN and Interconnect
  # spokes, which attach in the region their attachment lives in.
  location = "global"

  hub         = google_network_connectivity_hub.hub.id
  description = "VPC spoke: ${each.key}"

  linked_vpc_network {
    uri = each.value.network

    # Export ranges are stated rather than defaulted. A spoke that exports
    # everything makes every future subnet in that VPC reachable from every
    # other spoke the moment it is created, which is a routing change nobody
    # reviewed. Listing the supernet keeps the blast radius of a new subnet
    # inside the range that was agreed.
    include_export_ranges = each.value.include_export_ranges
    exclude_export_ranges = each.value.exclude_export_ranges
  }
}

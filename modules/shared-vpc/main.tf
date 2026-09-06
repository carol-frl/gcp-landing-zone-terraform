# Shared VPC host project and network. Service project attachment and subnet
# IAM are deliberately NOT here — those are per-team and belong to the project
# factory, which is the only thing that knows a team exists.

locals {
  # Callers pass folders/NNN because that is what the firewall policy and the
  # folder-structure module's outputs use. google_project wants the bare number.
  folder_numeric = replace(var.folder, "folders/", "")
}

resource "google_project" "host" {
  name       = "Shared VPC Host"
  project_id = var.host_project_id
  folder_id  = local.folder_numeric

  billing_account = var.billing_account

  auto_create_network = false
  deletion_policy     = "PREVENT"
}

resource "google_project_service" "host" {
  for_each = toset(["compute.googleapis.com", "dns.googleapis.com"])

  project            = google_project.host.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_shared_vpc_host_project" "host" {
  project    = google_project.host.project_id
  depends_on = [google_project_service.host]
}

resource "google_compute_network" "vpc" {
  name    = var.network_name
  project = google_project.host.project_id

  auto_create_subnetworks = false

  # GLOBAL so a Cloud Router in one region advertises on-prem routes to every
  # region. REGIONAL would contain the blast radius of a bad advertisement but
  # would mean on-prem cannot reach workloads outside the attachment's region
  # without a router in each. Revisit if the route table gets large.
  routing_mode = "GLOBAL"

  depends_on = [google_project_service.host]
}

# One subnet per team per region. CIDRs are supplied, not calculated — see the
# README for why index-based cidrsubnet() was rejected.
resource "google_compute_subnetwork" "team" {
  for_each = var.subnets

  name    = replace(each.key, "/", "-")
  project = google_project.host.project_id
  network = google_compute_network.vpc.id
  region  = each.value.region

  ip_cidr_range = each.value.primary

  # Lets VMs without an external IP reach Google APIs over internal addresses.
  # Without this, denying external IPs by org policy also cuts off Cloud
  # Storage and Artifact Registry, and teams route around the policy.
  private_ip_google_access = true

  # GKE needs pods and services as named secondary ranges that exist before the
  # cluster does. Provisioned here so a team can create a cluster without
  # touching the host project.
  secondary_ip_range {
    range_name    = "${replace(each.key, "/", "-")}-pods"
    ip_cidr_range = each.value.pods
  }

  secondary_ip_range {
    range_name    = "${replace(each.key, "/", "-")}-services"
    ip_cidr_range = each.value.services
  }

  # VPC flow logs are billed per GB of logs generated and are the single
  # easiest way to run up an unexpected networking bill. Off by default; turn
  # on per subnet when there is something to investigate.
  dynamic "log_config" {
    for_each = var.enable_flow_logs ? [1] : []
    content {
      aggregation_interval = "INTERVAL_5_SEC"
      flow_sampling        = 0.5
      metadata             = "INCLUDE_ALL_METADATA"
    }
  }
}

# --- Egress ----------------------------------------------------------------

# COST: Cloud NAT bills on four axes — an hourly rate per VM using the
# gateway (capped at 32 VMs), a per-GiB data processing charge, an hourly
# charge per external IP the gateway holds, and normal internet egress on top.
# A single idle gateway is roughly tens of dollars a month before any traffic.
# Verify current rates at https://cloud.google.com/nat/pricing before enabling.
#
# NOT required for the demo: the folder hierarchy, org policy and project
# factory all plan and apply without it. Default false so the repo can be
# stood up and torn down at no networking cost; the design is documented in
# docs/architecture.md regardless.
resource "google_compute_router" "nat" {
  for_each = var.enable_nat ? toset(var.regions) : toset([])

  name    = "${var.network_name}-nat-${each.value}"
  project = google_project.host.project_id
  network = google_compute_network.vpc.id
  region  = each.value
}

resource "google_compute_router_nat" "nat" {
  for_each = google_compute_router.nat

  name    = "${var.network_name}-nat-${each.key}"
  project = google_project.host.project_id
  router  = each.value.name
  region  = each.key

  # Auto-allocated addresses avoid pinning a static IP that later becomes an
  # allowlist entry somewhere and can never be changed. If a partner needs a
  # stable source IP, that is a reason to switch to MANUAL_ONLY and say so.
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    # Errors only. ALL is the setting that turns NAT logging into a bill.
    filter = "ERRORS_ONLY"
  }
}

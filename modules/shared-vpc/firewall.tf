# Hierarchical firewall policy, attached at the folder.
#
# These rules are evaluated BEFORE any VPC firewall rule in any project below.
# That makes a deny here final — a team cannot write an allow rule to get
# around it. It also makes an over-broad deny here an org-wide outage, which
# is why the baseline denies named management ports rather than denying
# everything and hoping the allows are complete.

resource "google_compute_firewall_policy" "baseline" {
  parent      = var.folder
  short_name  = "${var.network_name}-baseline"
  description = "Baseline ingress controls. Denies are final and cannot be overridden by project-level rules."
}

# Administrative access arrives through Identity-Aware Proxy, which
# authenticates the user before the packet reaches the VM. This range is IAP's
# and is not routable from the internet generally.
resource "google_compute_firewall_policy_rule" "allow_iap" {
  firewall_policy = google_compute_firewall_policy.baseline.name
  description     = "SSH and RDP via IAP TCP forwarding only."
  priority        = 1000
  direction       = "INGRESS"
  action          = "allow"
  enable_logging  = true

  match {
    src_ip_ranges = ["35.235.240.0/20"]

    layer4_configs {
      ip_protocol = "tcp"
      ports       = ["22", "3389"]
    }
  }
}

# Load balancer health checks come from fixed Google-owned ranges. Without
# this, backends are marked unhealthy and the deny below is blamed for it.
resource "google_compute_firewall_policy_rule" "allow_health_checks" {
  firewall_policy = google_compute_firewall_policy.baseline.name
  description     = "Google load balancer health check probes."
  priority        = 1100
  direction       = "INGRESS"
  action          = "allow"
  enable_logging  = false

  match {
    src_ip_ranges = ["35.191.0.0/16", "130.211.0.0/22"]

    layer4_configs {
      ip_protocol = "tcp"
    }
  }
}

# The actual baseline. These are the ports that get a VM compromised within
# hours of being exposed, and there is no legitimate reason to reach them from
# the internet in this org — IAP covers the real use case at priority 1000.
#
# Logging is on because a hit here is either an attack or a team about to file
# a ticket, and both are worth seeing. COST: firewall rules logging is billed
# through Cloud Logging ingestion; this rule should be low-volume, but check it
# if the logging bill moves.
resource "google_compute_firewall_policy_rule" "deny_management_ports" {
  firewall_policy = google_compute_firewall_policy.baseline.name
  description     = "Deny internet-facing SSH, RDP and SMB/NetBIOS."
  priority        = 2000
  direction       = "INGRESS"
  action          = "deny"
  enable_logging  = true

  match {
    src_ip_ranges = ["0.0.0.0/0"]

    layer4_configs {
      ip_protocol = "tcp"
      ports       = ["22", "3389", "135", "139", "445"]
    }

    layer4_configs {
      ip_protocol = "udp"
      ports       = ["137", "138", "139"]
    }
  }
}

# Everything else is delegated to VPC firewall rules in the service projects.
# Stated explicitly rather than relying on the implicit default, so that the
# boundary between platform-owned and team-owned rules is visible in the code.
resource "google_compute_firewall_policy_rule" "delegate" {
  firewall_policy = google_compute_firewall_policy.baseline.name
  description     = "Delegate all other ingress to project-level VPC firewall rules."
  priority        = 65000
  direction       = "INGRESS"
  action          = "goto_next"
  enable_logging  = false

  match {
    src_ip_ranges = ["0.0.0.0/0"]

    layer4_configs {
      ip_protocol = "all"
    }
  }
}

resource "google_compute_firewall_policy_association" "baseline" {
  name              = "${var.network_name}-baseline"
  firewall_policy   = google_compute_firewall_policy.baseline.id
  attachment_target = var.folder
}

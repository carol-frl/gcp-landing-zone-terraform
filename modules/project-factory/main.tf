# One team, in one environment. The caller loops; this module has no idea that
# other teams exist, which is what keeps the blast radius of a bad team entry
# to that team.

locals {
  project_id = "${var.project_prefix}-${var.team}-${var.environment_code}"

  # Service agents that need network access in the host project. These are
  # derived from the project number, so they cannot be referenced until the
  # project exists.
  cloudservices_agent = "serviceAccount:${google_project.team.number}@cloudservices.gserviceaccount.com"
  compute_agent       = "serviceAccount:service-${google_project.team.number}@compute-system.iam.gserviceaccount.com"
  container_agent     = "serviceAccount:service-${google_project.team.number}@container-engine-robot.iam.gserviceaccount.com"

  gke_enabled = contains(var.project_apis, "container.googleapis.com")

  # Flattened group -> role pairs so a single for_each covers both groups.
  folder_bindings = merge([
    for group_key, roles in var.folder_roles : {
      for role in roles :
      "${group_key}:${role}" => {
        member = "group:${var.config.groups[group_key]}"
        role   = role
      }
    }
  ]...)
}

resource "google_project" "team" {
  name       = "${var.config.display_name} ${title(var.environment)}"
  project_id = local.project_id
  folder_id  = replace(var.folder, "folders/", "")

  billing_account = var.billing_account

  auto_create_network = false
  deletion_policy     = var.environment == "production" ? "PREVENT" : "DELETE"

  labels = {
    team        = var.team
    environment = var.environment
    cost_centre = lower(var.config.cost_centre)
  }

  lifecycle {
    precondition {
      condition     = length(local.project_id) <= 30
      error_message = "Generated project ID \"${local.project_id}\" is ${length(local.project_id)} characters; GCP caps project IDs at 30. Shorten project_prefix or the team key in teams.yaml."
    }
  }
}

resource "google_project_service" "team" {
  for_each = toset(var.project_apis)

  project            = google_project.team.project_id
  service            = each.value
  disable_on_destroy = false
}

# --- Group IAM, bound at the team folder -----------------------------------

# Bound at the folder rather than the project so that a second project for this
# team in this environment inherits the same access without another binding.
#
# No basic roles. roles/editor spans every service in GCP including ones added
# after this was written, which makes it a grant nobody can describe the scope
# of. The predefined sets below are longer and are auditable.
resource "google_folder_iam_member" "team" {
  for_each = local.folder_bindings

  folder = var.folder
  role   = each.value.role
  member = each.value.member
}

# --- Shared VPC -------------------------------------------------------------

resource "google_compute_shared_vpc_service_project" "team" {
  host_project    = var.host_project_id
  service_project = google_project.team.project_id

  depends_on = [google_project_service.team]
}

# Subnet-level rather than host-project-level networkUser: this team can use
# its own subnet and cannot see or attach to another team's.
resource "google_compute_subnetwork_iam_member" "team" {
  for_each = toset([
    "group:${var.config.groups.admins}",
    "group:${var.config.groups.developers}",
    # Required for the project to create any instance in the shared subnet.
    local.cloudservices_agent,
    local.compute_agent,
  ])

  project    = var.host_project_id
  region     = var.subnet_region
  subnetwork = var.subnet_name
  role       = "roles/compute.networkUser"
  member     = each.value
}

# GKE additionally needs its service agent to manage firewall rules and
# secondary ranges in the host project. Only created when the container API is
# actually enabled — the service agent does not exist before then, and binding
# a non-existent principal fails the apply.
resource "google_project_iam_member" "gke_host_agent" {
  count = local.gke_enabled ? 1 : 0

  project = var.host_project_id
  role    = "roles/container.hostServiceAgentUser"
  member  = local.container_agent

  depends_on = [google_project_service.team]
}

resource "google_compute_subnetwork_iam_member" "gke_agent" {
  count = local.gke_enabled ? 1 : 0

  project    = var.host_project_id
  region     = var.subnet_region
  subnetwork = var.subnet_name
  role       = "roles/compute.networkUser"
  member     = local.container_agent
}

# --- Budget -----------------------------------------------------------------

# Costs nothing. Does nothing on its own either: with no notification channels
# the alert emails the billing account admins, who are usually not the people
# who can act on it. Wiring these to the team's own channel is unfinished work
# and is called out in docs/architecture.md.
resource "google_billing_budget" "team" {
  billing_account = var.billing_account
  display_name    = "${var.config.display_name} — ${var.environment}"

  budget_filter {
    projects = ["projects/${google_project.team.number}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.config.budget_usd[var.environment])
    }
  }

  # Three actuals and one forecast. The forecast alert is the only one that
  # arrives while there is still time to do something about it.
  dynamic "threshold_rules" {
    for_each = [0.5, 0.9, 1.0]
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }
}

# --- Team CI identity -------------------------------------------------------

resource "google_service_account" "ci" {
  account_id   = "team-ci"
  display_name = "${var.config.display_name} CI (${var.environment})"
  description  = "Impersonated by ${var.config.github_repo} via Workload Identity Federation. No keys."
  project      = google_project.team.project_id

  depends_on = [google_project_service.team]
}

resource "google_project_iam_member" "ci" {
  for_each = toset(var.ci_project_roles)

  project = google_project.team.project_id
  role    = each.value
  member  = google_service_account.ci.member
}

# Scoped to this team's repository only. The pool is shared; the binding is
# not. A token from data-platform's repo cannot impersonate payments' CI.
resource "google_service_account_iam_member" "ci_wif" {
  service_account_id = google_service_account.ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${var.workload_identity_pool_name}/attribute.repository/${var.config.github_repo}"
}

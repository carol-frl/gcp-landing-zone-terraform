# The bootstrap project. Deliberately separate from anything the landing zone
# later creates: it holds the state bucket and the CI identity, so a mistake in
# a team project can never reach the thing that governs every other apply.
resource "google_project" "bootstrap" {
  name       = "Landing Zone Bootstrap"
  project_id = var.project_id
  org_id     = var.org_id

  billing_account = var.billing_account

  # No default VPC. skipDefaultNetworkCreation is applied as org policy in
  # Weekend 2, but this project is created before that policy exists.
  auto_create_network = false

  # PREVENT is the provider default; stated explicitly because destroying this
  # project destroys the state for every other root.
  deletion_policy = "PREVENT"
}

locals {
  bootstrap_apis = [
    "cloudresourcemanager.googleapis.com", # folders, projects
    "cloudbilling.googleapis.com",         # linking billing to new projects
    "serviceusage.googleapis.com",         # enabling APIs on new projects
    "iam.googleapis.com",                  # service accounts
    "iamcredentials.googleapis.com",       # token exchange for WIF
    "sts.googleapis.com",                  # the WIF exchange itself
    "storage.googleapis.com",              # state bucket
    "orgpolicy.googleapis.com",            # Weekend 2 constraints
  ]

  # Everything the CI service account must do at the org node to build the
  # landing zone. Each is org-scoped because the resources it manages do not
  # exist yet and so cannot be targeted more narrowly.
  ci_org_roles = [
    "roles/resourcemanager.folderAdmin",    # create the folder hierarchy
    "roles/resourcemanager.projectCreator", # project factory
    "roles/orgpolicy.policyAdmin",          # org policy constraints
    "roles/compute.xpnAdmin",               # Shared VPC host/service attachment
  ]
}

resource "google_project_service" "bootstrap" {
  for_each = toset(local.bootstrap_apis)

  project = google_project.bootstrap.project_id
  service = each.value

  # Leave APIs enabled if this root is destroyed. Disabling an API is
  # org-visible and can break resources this root does not own.
  disable_on_destroy = false
}

# --- Terraform state -------------------------------------------------------

# Cost: standard storage, a few MB of state. Under $0.05/month at this size.
# Versioning multiplies object count, not meaningfully the bill.
resource "google_storage_bucket" "state" {
  name     = "${var.project_id}-tfstate"
  project  = google_project.bootstrap.project_id
  location = var.region

  # ACLs off. All access decisions live in IAM, where they are auditable.
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # A bucket holding state must not be emptiable by a stray destroy.
  force_destroy = false

  versioning {
    enabled = true
  }

  # Keep 10 non-current versions: enough to roll back a bad apply, bounded so
  # the bucket does not grow without limit.
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      num_newer_versions = 10
      with_state         = "ARCHIVED"
    }
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_project_service.bootstrap]
}

# Humans reach state through a group, never individually.
resource "google_storage_bucket_iam_member" "state_admins" {
  bucket = google_storage_bucket.state.name
  role   = "roles/storage.admin"
  member = var.terraform_admin_group
}

# --- CI identity -----------------------------------------------------------

resource "google_service_account" "ci" {
  account_id   = "terraform-ci"
  display_name = "Terraform CI"
  description  = "Impersonated by GitHub Actions via Workload Identity Federation. Has no keys."
  project      = google_project.bootstrap.project_id

  depends_on = [google_project_service.bootstrap]
}

# objectAdmin, not storage.admin: CI reads, writes and locks state objects but
# cannot change the bucket's versioning or retention settings.
resource "google_storage_bucket_iam_member" "ci_state" {
  bucket = google_storage_bucket.state.name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.ci.member
}

resource "google_organization_iam_member" "ci" {
  for_each = toset(local.ci_org_roles)

  org_id = var.org_id
  role   = each.value
  member = google_service_account.ci.member
}

# Attach billing to projects the factory creates. Scoped to the billing
# account rather than granted at the org.
resource "google_billing_account_iam_member" "ci" {
  billing_account_id = var.billing_account
  role               = "roles/billing.user"
  member             = google_service_account.ci.member
}

# --- Workload Identity Federation ------------------------------------------

resource "google_iam_workload_identity_pool" "github" {
  project                   = google_project.bootstrap.project_id
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"
  description               = "Federates GitHub Actions OIDC tokens. Replaces service account keys."

  depends_on = [google_project_service.bootstrap]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = google_project.bootstrap.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  # Without this condition the provider accepts a valid OIDC token from ANY
  # repository on GitHub. The token is genuine; the repo is not ours. This
  # single line is what makes keyless auth safe rather than a public door.
  attribute_condition = "assertion.repository == '${var.github_repo}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# The second half of the check: even a token that passes the provider
# condition can only impersonate this service account if it carries the
# matching repository attribute.
resource "google_service_account_iam_member" "ci_wif" {
  service_account_id = google_service_account.ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}

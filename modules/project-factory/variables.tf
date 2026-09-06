variable "team" {
  description = "Team key from teams.yaml. Becomes part of the project ID and a label."
  type        = string
}

variable "config" {
  description = "One team's entry from teams.yaml, decoded. The schema is documented in that file."

  type = object({
    display_name = string
    cost_centre  = string
    github_repo  = string
    groups = object({
      admins     = string
      developers = string
    })
    budget_usd = map(number)
  })

  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.config.github_repo))
    error_message = "github_repo must be owner/name."
  }
}

variable "environment" {
  description = "Environment name, matching a key in the team's budget_usd map and a folder in the hierarchy."
  type        = string
}

variable "environment_code" {
  description = "Short form of the environment used in project IDs, e.g. prd / nonprd. Project IDs cap at 30 characters."
  type        = string
}

variable "project_prefix" {
  description = "Org-wide prefix for generated project IDs."
  type        = string
}

variable "folder" {
  description = "This team's folder in this environment, as folders/NNN. Group IAM binds here."
  type        = string

  validation {
    condition     = can(regex("^folders/[0-9]+$", var.folder))
    error_message = "folder must be folders/NNN."
  }
}

variable "billing_account" {
  description = "Billing account for the project and the budget."
  type        = string
}

variable "host_project_id" {
  description = "Shared VPC host project for this environment."
  type        = string
}

variable "subnet_name" {
  description = "Name of the subnet delegated to this team, from the shared-vpc module."
  type        = string
}

variable "subnet_region" {
  description = "Region of that subnet."
  type        = string
}

variable "workload_identity_pool_name" {
  description = "Full WIF pool resource name from environments/bootstrap, projects/NNN/locations/global/workloadIdentityPools/github."
  type        = string
}

variable "project_apis" {
  description = "APIs enabled on the team project. Adding container.googleapis.com also creates the GKE host-project bindings."
  type        = list(string)

  default = [
    "compute.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ]
}

variable "folder_roles" {
  description = <<-DESC
    Roles granted to each group at the team folder, keyed by the group name in
    teams.yaml. Deliberately predefined roles rather than owner/editor/viewer:
    a basic role covers every service including ones released after this was
    written, so nobody can state its scope at review time.

    Override per environment to make production tighter than non-production.
  DESC

  type = map(list(string))

  default = {
    admins = [
      "roles/compute.admin",
      "roles/iam.serviceAccountAdmin",
      "roles/iam.serviceAccountUser",
      "roles/resourcemanager.projectIamAdmin",
      "roles/logging.admin",
    ]
    developers = [
      "roles/compute.viewer",
      "roles/logging.viewer",
      "roles/monitoring.viewer",
      "roles/errorreporting.viewer",
    ]
  }
}

variable "ci_project_roles" {
  description = "Roles the team's CI service account holds on its own project. Scoped to the project, never the folder — CI deploys into one environment at a time."
  type        = list(string)

  default = [
    "roles/compute.admin",
    "roles/iam.serviceAccountUser",
    "roles/storage.admin",
  ]
}

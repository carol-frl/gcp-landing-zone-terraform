variable "parent" {
  description = "Node this environment's folder is created under, as organizations/NNN or folders/NNN."
  type        = string

  validation {
    condition     = can(regex("^(organizations|folders)/[0-9]+$", var.parent))
    error_message = "parent must be organizations/NNN or folders/NNN."
  }
}

variable "billing_account" {
  description = "Billing account for the host project and every team project in this environment."
  type        = string
}

variable "project_prefix" {
  description = "Org-wide prefix for generated project IDs. Project IDs cap at 30 characters, so keep this short."
  type        = string

  validation {
    condition     = length(var.project_prefix) <= 8
    error_message = "project_prefix must be 8 characters or fewer, or generated project IDs will exceed the 30-character limit."
  }
}

variable "workload_identity_pool_name" {
  description = "workload_identity_provider's pool, from the environments/bootstrap outputs."
  type        = string
}

variable "default_region" {
  description = "Provider default region."
  type        = string
  default     = "europe-west4"
}

variable "list_constraints" {
  description = "Org policy list constraints applied at this environment's folder. See modules/org-policies."
  type = map(object({
    deny_all       = optional(bool, false)
    allowed_values = optional(list(string))
    denied_values  = optional(list(string))
  }))
}

variable "enable_nat" {
  description = "Cloud NAT in this environment. Bills whenever on — see modules/shared-vpc."
  type        = bool
  default     = false
}

variable "folder_roles" {
  description = "Roles per group at each team folder. Looser than production: admins keep projectIamAdmin so teams can self-serve access changes where nothing real is at risk."
  type        = map(list(string))

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

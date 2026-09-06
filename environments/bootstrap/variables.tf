variable "org_id" {
  description = "Numeric GCP organization ID. The CI service account is granted its landing-zone roles at this node."
  type        = string
}

variable "billing_account" {
  description = "Alphanumeric billing account ID (XXXXXX-XXXXXX-XXXXXX) linked to the bootstrap project."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository allowed to impersonate the CI service account, as owner/name. This is the only repo the Workload Identity provider will trust."
  type        = string

  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.github_repo))
    error_message = "github_repo must be in owner/name form, e.g. carol-frl/gcp-landing-zone-terraform."
  }
}

variable "project_id" {
  description = "Project ID for the bootstrap project. Must be globally unique; also used as the prefix for the state bucket name."
  type        = string
}

variable "region" {
  description = "Region for the state bucket. Bucket location is a permanent choice — moving state later means a manual copy."
  type        = string
  default     = "europe-west4"
}

variable "terraform_admin_group" {
  description = "Google Group with human read/write access to Terraform state. A group, never a user: individual bindings do not survive people changing teams."
  type        = string

  validation {
    condition     = startswith(var.terraform_admin_group, "group:")
    error_message = "terraform_admin_group must be a group principal, e.g. group:gcp-terraform-admins@example.com."
  }
}

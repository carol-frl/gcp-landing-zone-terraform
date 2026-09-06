variable "parent" {
  description = "Sandbox folder these resources are built under, as folders/NNN. Not the org root."
  type        = string

  validation {
    condition     = can(regex("^folders/[0-9]+$", var.parent))
    error_message = "parent must be folders/NNN. Applying this set at organizations/NNN is a deliberate promotion, not a default."
  }
}

variable "environments" {
  description = "Environment folders to create under the sandbox parent."
  type        = list(string)
  default     = ["production", "non-production"]
}

variable "teams" {
  description = "Team folders created inside each environment."
  type        = list(string)
}

variable "allowed_customer_ids" {
  description = "Cloud Identity customer IDs allowed in IAM policies, as [\"CUSTOMER_ID\"]. Find with: gcloud organizations describe ORG_ID --format='value(owner.directoryCustomerId)'."
  type        = list(string)
}

variable "allowed_locations" {
  description = "Locations resources may be created in, e.g. [\"in:eu-locations\"]. Value groups are documented at cloud.google.com/resource-manager/docs/organization-policy/defining-locations."
  type        = list(string)
}

variable "folder" {
  description = "Folder the hub project sits in, as folders/NNN. Should be a platform folder, not an environment folder — the hub belongs to neither environment."
  type        = string

  validation {
    condition     = can(regex("^folders/[0-9]+$", var.folder))
    error_message = "folder must be folders/NNN."
  }
}

variable "billing_account" {
  description = "Billing account for the hub project."
  type        = string
}

variable "project_id" {
  description = "Project ID for the hub project. Globally unique."
  type        = string
}

variable "hub_name" {
  description = "NCC hub name."
  type        = string
  default     = "lz-hub"
}

variable "vpc_spokes" {
  description = "VPC networks attached to the hub. Empty means the hub exists and nothing is billing. See modules/ncc-hub."
  type = map(object({
    network               = string
    include_export_ranges = optional(list(string))
    exclude_export_ranges = optional(list(string))
  }))
  default = {}
}

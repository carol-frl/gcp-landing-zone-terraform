variable "parent" {
  description = "Node the environment folders hang off, as organizations/NNN or folders/NNN."
  type        = string

  validation {
    condition     = can(regex("^(organizations|folders)/[0-9]+$", var.parent))
    error_message = "parent must be organizations/NNN or folders/NNN."
  }
}

variable "environments" {
  description = "Environment folder names, e.g. [\"production\", \"non-production\"]. These sit above teams."
  type        = list(string)

  validation {
    condition     = length(var.environments) > 0
    error_message = "At least one environment is required."
  }
}

variable "teams" {
  description = "Team folder names. Each team gets one folder inside every environment."
  type        = list(string)
}

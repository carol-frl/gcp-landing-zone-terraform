terraform {
  required_version = ">= 1.13.4"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # backend "gcs" {
  #   bucket = "REPLACE-WITH-state_bucket-OUTPUT"
  #   prefix = "network-hub"
  # }
}

provider "google" {
  region = var.default_region
}

variable "default_region" {
  description = "Provider default region. The hub itself is global."
  type        = string
  default     = "europe-west4"
}

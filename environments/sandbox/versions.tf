terraform {
  required_version = ">= 1.13.4"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # Fill in the state_bucket output from environments/bootstrap, then
  # uncomment. Unlike bootstrap, this root has no reason to start local.
  #
  # backend "gcs" {
  #   bucket = "REPLACE-WITH-state_bucket-OUTPUT"
  #   prefix = "sandbox"
  # }
}

provider "google" {
  region = var.region
}

variable "region" {
  description = "Default provider region. No regional resources are created by this root yet."
  type        = string
  default     = "europe-west4"
}

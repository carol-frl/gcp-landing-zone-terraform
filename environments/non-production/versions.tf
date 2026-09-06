terraform {
  required_version = ">= 1.13.4"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # Fill in the state_bucket output from environments/bootstrap, then uncomment.
  #
  # backend "gcs" {
  #   bucket = "REPLACE-WITH-state_bucket-OUTPUT"
  #   prefix = "non-production"
  # }
}

provider "google" {
  region = var.default_region
}

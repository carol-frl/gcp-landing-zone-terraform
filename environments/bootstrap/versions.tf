terraform {
  required_version = ">= 1.13.4"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # Bootstrap is the chicken-and-egg root: it creates the bucket that every
  # other root stores state in, so its own first apply runs against local
  # state using your own credentials. After that apply, uncomment the block
  # below and run `terraform init -migrate-state` to move this root's state
  # into the bucket it just created.
  #
  # backend "gcs" {
  #   bucket = "REPLACE-WITH-state_bucket-OUTPUT"
  #   prefix = "bootstrap"
  # }
}

# No default project on the provider: this root creates the project it then
# builds into, so every resource names its project explicitly.
provider "google" {
  region = var.region
}

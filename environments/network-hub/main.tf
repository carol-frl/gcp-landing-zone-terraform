# The transit layer. Applied after both environment roots, because its spokes
# reference networks those roots create.
#
# Deliberately its own root rather than a module call inside production: a hub
# that spans environments cannot be owned by one of them, and attaching
# non-production to the hub should not be a change to the production state file.

resource "google_project" "hub" {
  name       = "Network Hub"
  project_id = var.project_id
  folder_id  = replace(var.folder, "folders/", "")

  billing_account = var.billing_account

  auto_create_network = false
  deletion_policy     = "PREVENT"
}

resource "google_project_service" "hub" {
  for_each = toset([
    "compute.googleapis.com",
    "networkconnectivity.googleapis.com",
  ])

  project            = google_project.hub.project_id
  service            = each.value
  disable_on_destroy = false
}

module "hub" {
  source = "../../modules/ncc-hub"

  project_id = google_project.hub.project_id
  hub_name   = var.hub_name

  # Empty by default. Each entry bills a spoke-hour for as long as it exists.
  vpc_spokes = var.vpc_spokes

  depends_on = [google_project_service.hub]
}

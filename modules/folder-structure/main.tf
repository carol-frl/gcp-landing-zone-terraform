# Environment above team: org -> production -> payments
#                              -> non-production -> payments
#
# The reasoning belongs in docs/decisions/001-folder-hierarchy.md. The shape
# it produces is here.

locals {
  # One folder per environment/team pair, keyed by the path it sits at so the
  # output map reads the same way the console does.
  team_folders = {
    for pair in setproduct(var.environments, var.teams) :
    "${pair[0]}/${pair[1]}" => {
      environment = pair[0]
      team        = pair[1]
    }
  }
}

resource "google_folder" "environment" {
  for_each = toset(var.environments)

  display_name = each.value
  parent       = var.parent

  # False because this is a demo org that gets rebuilt. In a real org this
  # stays true: an accidental folder delete takes every project under it.
  deletion_protection = false
}

resource "google_folder" "team" {
  for_each = local.team_folders

  display_name = each.value.team
  parent       = google_folder.environment[each.value.environment].name

  deletion_protection = false
}

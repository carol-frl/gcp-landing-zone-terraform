locals {
  environment      = "production"
  environment_code = "prd"

  # The contract. Adding a team here is the only change required to give it
  # folders, a project, network, IAM, a budget and a CI identity.
  teams = yamldecode(file("${path.module}/../../teams/teams.yaml")).teams

  regions = distinct([for t in local.teams : t.region])

  subnets = {
    for name, t in local.teams :
    "${name}/${t.region}" => {
      region   = t.region
      primary  = t.networks[local.environment].primary
      pods     = t.networks[local.environment].pods
      services = t.networks[local.environment].services
    }
  }
}

module "folders" {
  source = "../../modules/folder-structure"

  parent       = var.parent
  environments = [local.environment]
  teams        = keys(local.teams)
}

module "org_policies" {
  source = "../../modules/org-policies"

  parent           = module.folders.folder_names[local.environment]
  list_constraints = var.list_constraints
}

module "network" {
  source = "../../modules/shared-vpc"

  folder          = module.folders.folder_names[local.environment]
  billing_account = var.billing_account
  host_project_id = "${var.project_prefix}-host-${local.environment_code}"
  network_name    = "shared-${local.environment_code}"
  regions         = local.regions
  subnets         = local.subnets

  enable_nat = var.enable_nat
}

module "team" {
  source   = "../../modules/project-factory"
  for_each = local.teams

  team = each.key

  # Built explicitly rather than passing the raw YAML entry, so the module's
  # contract is visible here and a new field in teams.yaml cannot arrive in
  # the module unnoticed.
  config = {
    display_name = each.value.display_name
    cost_centre  = each.value.cost_centre
    github_repo  = each.value.github_repo
    groups       = each.value.groups
    budget_usd   = each.value.budget_usd
  }

  environment      = local.environment
  environment_code = local.environment_code
  project_prefix   = var.project_prefix

  folder          = module.folders.folder_names["${local.environment}/${each.key}"]
  billing_account = var.billing_account

  host_project_id = module.network.host_project_id
  subnet_name     = module.network.subnet_self_links["${each.key}/${each.value.region}"].name
  subnet_region   = each.value.region

  workload_identity_pool_name = var.workload_identity_pool_name

  folder_roles = var.folder_roles
}

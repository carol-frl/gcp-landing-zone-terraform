# Org policy v2 (google_org_policy_policy). The v1 google_organization_policy
# resource cannot target folders uniformly and is not used here.
#
# Both maps are variables so a sandbox folder can run a looser set than
# production without forking the module.

resource "google_org_policy_policy" "boolean" {
  for_each = var.boolean_constraints

  name   = "${var.parent}/policies/${each.key}"
  parent = var.parent

  spec {
    # A child folder cannot loosen what an ancestor enforced.
    inherit_from_parent = var.inherit_from_parent

    rules {
      enforce = each.value ? "TRUE" : "FALSE"
    }
  }
}

resource "google_org_policy_policy" "list" {
  for_each = var.list_constraints

  name   = "${var.parent}/policies/${each.key}"
  parent = var.parent

  spec {
    inherit_from_parent = var.inherit_from_parent

    rules {
      # deny_all and the allow/deny value lists are mutually exclusive per
      # rule; the variable's validation enforces that a caller sets one shape.
      deny_all = each.value.deny_all ? "TRUE" : null

      dynamic "values" {
        for_each = each.value.deny_all ? [] : [1]
        content {
          allowed_values = each.value.allowed_values
          denied_values  = each.value.denied_values
        }
      }
    }
  }
}

output "applied_constraints" {
  description = "Every constraint this module set at var.parent, for asserting in tests or diffing environments."
  value       = sort(concat(keys(var.boolean_constraints), keys(var.list_constraints)))
}

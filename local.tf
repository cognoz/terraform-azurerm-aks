###############################################################################
# Locals — centralize derived values and the "computed name" pattern
###############################################################################

locals {
  # dns_prefix derived from cluster name, stripped of underscores (AKS rule).
  dns_prefix = replace(var.cluster_name, "_", "-")

  # Merge module-level tags with a managed-by marker.
  tags = merge(
    {
      managed_by = "terraform"
      module     = "terraform-azurerm-aks"
    },
    var.tags,
  )

  # Feature flags expressed as booleans keep the resource blocks readable.
  monitoring_enabled = var.log_analytics_workspace_id != null
  use_user_identity  = var.identity_type == "UserAssigned"
}

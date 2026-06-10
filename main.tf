###############################################################################
# Cluster
###############################################################################

# Trivy ignore scoped to this resource. network_policy defaults to "azure" via
# the network_profile variable, but Trivy cannot always resolve a default that
# is emitted through a dynamic block. Both examples set secure values; the
# module's defaults are secure. AZU-0041 (API server IP ranges) is satisfied by
# the examples passing api_server_authorized_ip_ranges, so it needs no ignore.
#trivy:ignore:AZU-0043
resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = local.dns_prefix
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier

  private_cluster_enabled           = var.private_cluster_enabled
  role_based_access_control_enabled = true
  local_account_disabled            = var.local_account_disabled
  oidc_issuer_enabled               = var.oidc_issuer_enabled
  workload_identity_enabled         = var.workload_identity_enabled

  default_node_pool {
    name                         = var.default_node_pool.name
    vm_size                      = var.default_node_pool.vm_size
    node_count                   = var.default_node_pool.enable_auto_scaling ? null : var.default_node_pool.node_count
    auto_scaling_enabled         = var.default_node_pool.enable_auto_scaling
    min_count                    = var.default_node_pool.enable_auto_scaling ? var.default_node_pool.min_count : null
    max_count                    = var.default_node_pool.enable_auto_scaling ? var.default_node_pool.max_count : null
    os_disk_size_gb              = var.default_node_pool.os_disk_size_gb
    only_critical_addons_enabled = var.default_node_pool.only_critical_addons
    orchestrator_version         = var.default_node_pool.orchestrator_version
    zones                        = var.default_node_pool.zones
    vnet_subnet_id               = var.vnet_subnet_id

    dynamic "upgrade_settings" {
      for_each = var.default_node_pool.max_surge != null ? [1] : []
      content {
        max_surge = var.default_node_pool.max_surge
      }
    }

    tags = local.tags
  }

  # Conditional identity block: SystemAssigned needs no extra args, while
  # UserAssigned must pass the identity id. A dynamic block keeps it to one.
  dynamic "identity" {
    for_each = local.use_user_identity ? [] : [1]
    content {
      type = "SystemAssigned"
    }
  }

  dynamic "identity" {
    for_each = local.use_user_identity ? [1] : []
    content {
      type         = "UserAssigned"
      identity_ids = [var.user_assigned_identity_id]
    }
  }

  # AAD / Azure RBAC integration is only emitted when requested.
  dynamic "azure_active_directory_role_based_access_control" {
    for_each = var.azure_rbac_enabled ? [1] : []
    content {
      azure_rbac_enabled     = true
      tenant_id              = var.aad_tenant_id
      admin_group_object_ids = var.admin_group_object_ids
    }
  }

  # Network profile only when the caller overrides defaults.
  dynamic "network_profile" {
    for_each = var.network_profile != null ? [var.network_profile] : []
    content {
      network_plugin      = network_profile.value.network_plugin
      network_plugin_mode = network_profile.value.network_plugin_mode
      network_policy      = network_profile.value.network_policy
      service_cidr        = network_profile.value.service_cidr
      dns_service_ip      = network_profile.value.dns_service_ip
      pod_cidr            = network_profile.value.pod_cidr
    }
  }

  # Restrict the public API server to known IP ranges when provided.
  # Skipped for private clusters (no public endpoint to restrict) and when
  # no ranges are given.
  dynamic "api_server_access_profile" {
    for_each = (!var.private_cluster_enabled && length(var.api_server_authorized_ip_ranges) > 0) ? [1] : []
    content {
      authorized_ip_ranges = var.api_server_authorized_ip_ranges
    }
  }

  # Monitoring addon — the classic "optional feature via nullable input" pattern.
  dynamic "oms_agent" {
    for_each = local.monitoring_enabled ? [1] : []
    content {
      log_analytics_workspace_id      = var.log_analytics_workspace_id
      msi_auth_for_monitoring_enabled = var.oms_msi_auth_enabled
    }
  }

  # Microsoft Defender for Containers — enabled when a workspace id is supplied.
  dynamic "microsoft_defender" {
    for_each = var.microsoft_defender_log_analytics_workspace_id != null ? [1] : []
    content {
      log_analytics_workspace_id = var.microsoft_defender_log_analytics_workspace_id
    }
  }

  tags = local.tags

  lifecycle {
    # The control plane often bumps the patch version out-of-band; ignore it
    # so routine applies don't fight Azure. Callers pin minor explicitly.
    ignore_changes = [
      kubernetes_version,
    ]
  }
}

###############################################################################
# Additional node pools — for_each over the input map
###############################################################################

resource "azurerm_kubernetes_cluster_node_pool" "this" {
  for_each = var.additional_node_pools

  name                  = each.key
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = each.value.vm_size
  mode                  = each.value.mode
  orchestrator_version  = each.value.orchestrator_version

  node_count           = each.value.enable_auto_scaling ? null : each.value.node_count
  auto_scaling_enabled = each.value.enable_auto_scaling
  min_count            = each.value.enable_auto_scaling ? each.value.min_count : null
  max_count            = each.value.enable_auto_scaling ? each.value.max_count : null

  os_disk_size_gb = each.value.os_disk_size_gb
  zones           = each.value.zones
  vnet_subnet_id  = var.vnet_subnet_id

  priority        = each.value.priority
  spot_max_price  = each.value.priority == "Spot" ? each.value.spot_max_price : null
  eviction_policy = each.value.priority == "Spot" ? "Delete" : null

  # Spot pools must carry the scheduling taint so only tolerant workloads land.
  node_labels = each.value.priority == "Spot" ? merge(each.value.node_labels, {
    "kubernetes.azure.com/scalesetpriority" = "spot"
  }) : each.value.node_labels

  node_taints = each.value.priority == "Spot" ? concat(each.value.node_taints, [
    "kubernetes.azure.com/scalesetpriority=spot:NoSchedule"
  ]) : each.value.node_taints

  tags = local.tags
}

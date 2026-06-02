###############################################################################
# Required inputs
###############################################################################

variable "resource_group_name" {
  description = "Name of the resource group in which to create the cluster."
  type        = string
}

variable "location" {
  description = "Azure region for the cluster (e.g. \"swedencentral\")."
  type        = string
}

variable "cluster_name" {
  description = <<-EOT
    Name of the AKS cluster. Must be 1-63 chars, alphanumeric, hyphens and
    underscores allowed, and start/end with an alphanumeric character.
  EOT
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9_-]{0,61}[a-zA-Z0-9]$", var.cluster_name))
    error_message = "cluster_name must be 1-63 chars, alphanumeric plus '-'/'_', and start and end alphanumeric."
  }
}

###############################################################################
# Kubernetes / control plane
###############################################################################

variable "kubernetes_version" {
  description = "Kubernetes control plane version. Null lets AKS pick the default."
  type        = string
  default     = null

  validation {
    # Either null, or a semantic-ish version like 1.29 or 1.29.4
    condition     = var.kubernetes_version == null || can(regex("^\\d+\\.\\d+(\\.\\d+)?$", var.kubernetes_version))
    error_message = "kubernetes_version must be null or a version string like \"1.29\" or \"1.29.4\"."
  }
}

variable "sku_tier" {
  description = "Control plane SKU tier. \"Standard\" gives the uptime SLA."
  type        = string
  default     = "Free"

  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "sku_tier must be one of: Free, Standard, Premium."
  }
}

variable "private_cluster_enabled" {
  description = "Whether the API server is exposed only on a private IP."
  type        = bool
  default     = false
}

###############################################################################
# Default (system) node pool
###############################################################################

variable "default_node_pool" {
  description = "Configuration for the required system node pool."
  type = object({
    name                 = optional(string, "system")
    vm_size              = optional(string, "Standard_D2s_v5")
    node_count           = optional(number, 2)
    min_count            = optional(number, null)
    max_count            = optional(number, null)
    enable_auto_scaling  = optional(bool, false)
    os_disk_size_gb      = optional(number, 128)
    only_critical_addons = optional(bool, true)
    zones                = optional(list(string), ["1", "2", "3"])
  })
  default = {}

  validation {
    condition     = var.default_node_pool.node_count >= 1
    error_message = "default_node_pool.node_count must be at least 1."
  }

  validation {
    # If autoscaling is on, both bounds must be set and coherent.
    condition = (
      !var.default_node_pool.enable_auto_scaling
      ) || (
      var.default_node_pool.min_count != null &&
      var.default_node_pool.max_count != null &&
      var.default_node_pool.min_count <= var.default_node_pool.max_count
    )
    error_message = "When enable_auto_scaling is true, min_count and max_count must be set with min_count <= max_count."
  }
}

###############################################################################
# Additional (user) node pools — demonstrates for_each over a map
###############################################################################

variable "additional_node_pools" {
  description = <<-EOT
    Map of extra node pools keyed by pool name. Each value configures a
    user node pool. Spot pools are supported via the priority field.
  EOT
  type = map(object({
    vm_size             = string
    node_count          = optional(number, 1)
    min_count           = optional(number, null)
    max_count           = optional(number, null)
    enable_auto_scaling = optional(bool, false)
    mode                = optional(string, "User")
    priority            = optional(string, "Regular") # Regular | Spot
    spot_max_price      = optional(number, -1)
    os_disk_size_gb     = optional(number, 128)
    zones               = optional(list(string), ["1", "2", "3"])
    node_labels         = optional(map(string), {})
    node_taints         = optional(list(string), [])
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.additional_node_pools : contains(["Regular", "Spot"], v.priority)
    ])
    error_message = "Each additional node pool priority must be \"Regular\" or \"Spot\"."
  }
}

###############################################################################
# Networking
###############################################################################

variable "network_profile" {
  description = "Optional network profile overrides. Null uses AKS defaults (kubenet)."
  type = object({
    network_plugin = optional(string, "azure")
    network_policy = optional(string, "azure")
    service_cidr   = optional(string, null)
    dns_service_ip = optional(string, null)
  })
  default = null
}

variable "vnet_subnet_id" {
  description = "Subnet ID to deploy node pools into. Null for AKS-managed network."
  type        = string
  default     = null
}

###############################################################################
# Identity & RBAC
###############################################################################

variable "identity_type" {
  description = "Managed identity type: SystemAssigned or UserAssigned."
  type        = string
  default     = "SystemAssigned"

  validation {
    condition     = contains(["SystemAssigned", "UserAssigned"], var.identity_type)
    error_message = "identity_type must be SystemAssigned or UserAssigned."
  }
}

variable "user_assigned_identity_id" {
  description = "Required when identity_type is UserAssigned."
  type        = string
  default     = null
}

variable "azure_rbac_enabled" {
  description = "Enable Azure RBAC for Kubernetes authorization."
  type        = bool
  default     = true
}

variable "admin_group_object_ids" {
  description = "AAD group object IDs granted cluster-admin via AKS-managed AAD."
  type        = list(string)
  default     = []
}

###############################################################################
# Observability — optional feature toggled by passing a workspace id
###############################################################################

variable "log_analytics_workspace_id" {
  description = "If set, enables the OMS/monitoring addon pointed at this workspace."
  type        = string
  default     = null
}

###############################################################################
# Tags
###############################################################################

variable "tags" {
  description = "Tags applied to all resources created by the module."
  type        = map(string)
  default     = {}
}

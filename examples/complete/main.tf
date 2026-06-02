# Complete usage: autoscaling system pool, a regular + a spot user pool,
# Azure CNI, AAD/Azure RBAC, and the monitoring addon.

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "this" {
  name     = "rg-aks-complete-demo"
  location = "swedencentral"
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "law-aks-complete-demo"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

module "aks" {
  source = "../../"

  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  cluster_name        = "aks-complete-demo"
  kubernetes_version  = "1.29"
  sku_tier            = "Standard"

  default_node_pool = {
    vm_size             = "Standard_D4s_v5"
    enable_auto_scaling = true
    min_count           = 2
    max_count           = 5
  }

  additional_node_pools = {
    workload = {
      vm_size             = "Standard_D4s_v5"
      enable_auto_scaling = true
      min_count           = 1
      max_count           = 10
    }
    spot = {
      vm_size             = "Standard_D4s_v5"
      priority            = "Spot"
      spot_max_price      = -1
      enable_auto_scaling = true
      min_count           = 0
      max_count           = 20
    }
  }

  network_profile = {
    network_plugin = "azure"
    network_policy = "azure"
  }

  azure_rbac_enabled         = true
  admin_group_object_ids     = ["00000000-0000-0000-0000-000000000000"]
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  tags = {
    environment = "demo"
    owner       = "platform-team"
  }
}

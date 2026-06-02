# Minimal usage: just the required inputs, everything else defaulted.

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "this" {
  name     = "rg-aks-minimal-demo"
  location = "swedencentral"
}

module "aks" {
  source = "../../"

  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  cluster_name        = "aks-minimal-demo"

  # Restrict the public API server. Replace with your egress/operator CIDRs.
  api_server_authorized_ip_ranges = ["203.0.113.0/24"]
}

output "cluster_id" {
  value = module.aks.cluster_id
}

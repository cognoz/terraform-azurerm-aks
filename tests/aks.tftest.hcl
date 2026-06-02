# Native `terraform test` suite (terraform >= 1.6).
# These use command = plan so they run WITHOUT real Azure credentials —
# perfect for CI. They exercise validation rules and computed logic.

# A reusable mock provider so plan doesn't try to authenticate.
mock_provider "azurerm" {}
mock_provider "random" {}

variables {
  resource_group_name = "rg-test"
  location            = "swedencentral"
  cluster_name        = "aks-unit-test"
}

# 1. Defaults produce a single system node pool with expected size.
run "defaults_apply_cleanly" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.this.default_node_pool[0].vm_size == "Standard_D2s_v5"
    error_message = "Default system pool vm_size should be Standard_D2s_v5."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.dns_prefix == "aks-unit-test"
    error_message = "dns_prefix should derive from the cluster name."
  }
}

# 2. Underscores in the cluster name are converted in the dns_prefix.
run "dns_prefix_strips_underscores" {
  command = plan

  variables {
    cluster_name = "aks_with_underscores"
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.dns_prefix == "aks-with-underscores"
    error_message = "Underscores must be replaced with hyphens in dns_prefix."
  }
}

# 3. Invalid cluster name is rejected by the variable validation block.
run "rejects_invalid_cluster_name" {
  command = plan

  variables {
    cluster_name = "-bad-name-"
  }

  expect_failures = [
    var.cluster_name,
  ]
}

# 4. Autoscaling without bounds fails the cross-field validation.
run "rejects_autoscaling_without_bounds" {
  command = plan

  variables {
    default_node_pool = {
      enable_auto_scaling = true
      # min_count / max_count intentionally omitted
    }
  }

  expect_failures = [
    var.default_node_pool,
  ]
}

# 5. Spot node pool gets the scheduling taint injected automatically.
run "spot_pool_gets_taint" {
  command = plan

  variables {
    additional_node_pools = {
      spot = {
        vm_size  = "Standard_D2s_v5"
        priority = "Spot"
      }
    }
  }

  assert {
    condition = contains(
      azurerm_kubernetes_cluster_node_pool.this["spot"].node_taints,
      "kubernetes.azure.com/scalesetpriority=spot:NoSchedule"
    )
    error_message = "Spot pools must receive the spot NoSchedule taint."
  }
}

# 6. Invalid sku_tier is rejected.
run "rejects_bad_sku_tier" {
  command = plan

  variables {
    sku_tier = "Ultra"
  }

  expect_failures = [
    var.sku_tier,
  ]
}

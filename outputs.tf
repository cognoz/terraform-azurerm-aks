output "cluster_id" {
  description = "Resource ID of the AKS cluster."
  value       = azurerm_kubernetes_cluster.this.id
}

output "cluster_name" {
  description = "Name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.this.name
}

output "cluster_fqdn" {
  description = "FQDN of the cluster API server (private FQDN if private cluster)."
  value = var.private_cluster_enabled ? (
    azurerm_kubernetes_cluster.this.private_fqdn
  ) : azurerm_kubernetes_cluster.this.fqdn
}

output "node_resource_group" {
  description = "Auto-generated resource group holding the cluster's infra (MC_*)."
  value       = azurerm_kubernetes_cluster.this.node_resource_group
}

output "kubelet_identity" {
  description = "Object/client/principal ids of the kubelet identity (for ACR pulls etc.)."
  value       = azurerm_kubernetes_cluster.this.kubelet_identity
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL — useful for workload identity federation."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

# Sensitive outputs: kubeconfig contains client certs/tokens.
output "kube_config_raw" {
  description = "Raw kubeconfig for the cluster. Treat as a secret."
  value       = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive   = true
}

output "kube_config" {
  description = "Structured kubeconfig attributes (host, certs). Sensitive."
  value       = azurerm_kubernetes_cluster.this.kube_config
  sensitive   = true
}

output "additional_node_pool_ids" {
  description = "Map of additional node pool name => resource id."
  value       = { for k, np in azurerm_kubernetes_cluster_node_pool.this : k => np.id }
}

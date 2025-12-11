####################################################################################################
###                                                                                              ###
###                                       AKS NODE POOL                                          ###
###                                                                                              ###
####################################################################################################

# GitOps Node Pool
resource "azurerm_kubernetes_cluster_node_pool" "gitops_prod" {
  name                  = "gitops"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.gitops_aks.id
  vm_size               = length(var.node_pool_vm_size) > 0 ? var.node_pool_vm_size[0] : "Standard_D2s_v3"
  node_count            = var.node_pool_desired_size
  vnet_subnet_id        = var.subnet_ids[0]

  # Enable autoscaling
  enable_auto_scaling = var.enable_cluster_autoscaler
  min_count           = var.node_pool_min_size
  max_count           = var.node_pool_max_size

  # Node pool settings
  os_type         = "Linux"
  os_disk_type    = "Managed"
  os_disk_size_gb = 30

  # Node labels
  node_labels = {
    "cluster-autoscaler-enabled" = "true"
    "cluster-autoscaler-owned"   = azurerm_kubernetes_cluster.gitops_aks.name
    "budget"                      = var.proc_budget
    "purpose"                     = "gitops"
  }

  # Upgrade settings
  upgrade_settings {
    max_surge = "33%"
  }

  depends_on = [
    azurerm_kubernetes_cluster.gitops_aks
  ]

  lifecycle {
    ignore_changes = [
      node_count
    ]
  }
}


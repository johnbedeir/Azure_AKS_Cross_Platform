####################################################################################################
###                                                                                              ###
###                                      CLUSTER READY WAIT                                       ###
###                                                                                              ###
####################################################################################################

# Wait for cluster to be fully ready before deploying Kubernetes resources
# This ensures the kube_config credentials are valid and the API server is accessible
# Increased wait time to ensure cluster API server is fully ready and credentials are valid
resource "time_sleep" "wait_for_cluster_ready" {
  depends_on = [
    azurerm_kubernetes_cluster.gitops_aks,
    azurerm_kubernetes_cluster_node_pool.gitops_prod
  ]

  create_duration = "120s" # Wait 120 seconds for cluster to be fully ready and API server accessible
}


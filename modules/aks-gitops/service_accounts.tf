####################################################################################################
###                                                                                              ###
###                                   AKS SERVICE ACCOUNTS                                        ###
###                                                                                              ###
####################################################################################################

# Azure uses Managed Identities instead of service accounts
# The cluster uses a SystemAssigned managed identity (created in aks.tf)
# This file is for any additional managed identities if needed

# Managed Identity for ArgoCD repository access
resource "azurerm_user_assigned_identity" "argocd_repo_access" {
  count = var.enable_argocd ? 1 : 0

  name                = "${replace(local.cluster_name, "-", "")}-argocd-repo"
  location            = var.region
  resource_group_name = var.resource_group_name

  tags = {
    Budget = var.proc_budget
    Env    = var.environment
  }
}

# Managed Identity for ArgoCD cross-cluster access
resource "azurerm_user_assigned_identity" "argocd_cross_cluster_access" {
  count = var.enable_argocd ? 1 : 0

  name                = "${replace(local.cluster_name, "-", "")}-argocd-x"
  location            = var.region
  resource_group_name = var.resource_group_name

  tags = {
    Budget = var.proc_budget
    Env    = var.environment
  }
}

# Grant the managed identity permissions to access AKS clusters
resource "azurerm_role_assignment" "argocd_cross_cluster_aks" {
  count = var.enable_argocd ? 1 : 0

  scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${var.target_cluster_resource_group}/providers/Microsoft.ContainerService/managedClusters/${var.target_cluster_name}"
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azurerm_user_assigned_identity.argocd_cross_cluster_access[0].principal_id
}


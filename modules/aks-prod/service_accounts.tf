####################################################################################################
###                                                                                              ###
###                                   AKS SERVICE ACCOUNTS                                        ###
###                                                                                              ###
####################################################################################################

# Azure uses Managed Identities instead of service accounts
# The cluster uses a SystemAssigned managed identity (created in aks.tf)
# This file is for any additional managed identities if needed

# Managed Identity for ArgoCD GitOps access from external clusters
resource "azurerm_user_assigned_identity" "argocd_gitops_access" {
  count = var.enable_argocd_access ? 1 : 0

  name                = "${replace(local.cluster_name, "-", "")}-argocd-gitops"
  location            = var.region
  resource_group_name = var.resource_group_name

  tags = {
    Budget = var.proc_budget
    Env    = var.environment
  }
}

# Grant the managed identity permissions to access AKS cluster
resource "azurerm_role_assignment" "argocd_gitops_aks" {
  count = var.enable_argocd_access ? 1 : 0

  scope                = azurerm_kubernetes_cluster.prod_aks.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azurerm_user_assigned_identity.argocd_gitops_access[0].principal_id
}


####################################################################################################
###                                                                                              ###
###                                  CROSS-CLUSTER COMMUNICATION                                  ###
###                                                                                              ###
####################################################################################################

# Managed Identity for ArgoCD to manage external clusters
# This is created in service_accounts.tf
# Cross-cluster access is configured via:
# 1. Managed Identity with Azure Kubernetes Service Cluster User Role
# 2. ArgoCD cluster secret (created in argocd.tf)
# 3. Bearer token authentication (configured manually via ArgoCD UI or CLI)

# Note: Cluster secrets for cross-cluster connectivity are managed via ArgoCD cluster secrets
# See argocd.tf for the cluster secret configuration
# Bearer tokens should be configured manually to avoid IAM role timeout issues


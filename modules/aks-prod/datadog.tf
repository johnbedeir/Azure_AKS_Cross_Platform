####################################################################################################
###                                                                                              ###
###                                      DATADOG AGENT                                          ###
###                                                                                              ###
####################################################################################################

# Get Datadog API key from Azure Key Vault
# Note: Secret must be created in root secrets.tf before this data source can read it
# Using try() to handle cases where key_vault_id might be empty
data "azurerm_key_vault_secret" "datadog_api_key" {
  count        = var.enable_datadog ? 1 : 0
  name         = var.datadog_api_secret_name
  key_vault_id = var.key_vault_id

  depends_on = [
    azurerm_kubernetes_cluster.prod_aks
  ]
}

# Create Kubernetes secret for Datadog API key
resource "kubernetes_secret" "datadog_api_key" {
  count = var.enable_datadog ? 1 : 0

  metadata {
    name      = "datadog-secret"
    namespace = "kube-system"
  }

  data = {
    "api-key" = var.enable_datadog ? try(data.azurerm_key_vault_secret.datadog_api_key[0].value, "") : ""
  }

  depends_on = [
    azurerm_kubernetes_cluster.prod_aks,
    azurerm_kubernetes_cluster_node_pool.prod,
    time_sleep.wait_for_cluster_ready
  ]
}

# Helm release for Datadog agent
resource "helm_release" "datadog_agent" {
  count = var.enable_datadog ? 1 : 0

  name             = "datadog"
  namespace        = "kube-system"
  repository       = "https://helm.datadoghq.com"
  chart            = "datadog"
  version          = "3.116.3"
  create_namespace = false
  timeout          = 600
  wait             = false

  set {
    name  = "datadog.apiKeyExistingSecret"
    value = kubernetes_secret.datadog_api_key[0].metadata[0].name
  }

  set {
    name  = "datadog.apiKeySecretKey"
    value = "api-key"
  }

  set {
    name  = "datadog.site"
    value = "datadoghq.com"
  }

  set {
    name  = "datadog.clusterName"
    value = azurerm_kubernetes_cluster.prod_aks.name
  }

  set {
    name  = "clusterAgent.enabled"
    value = "true"
  }

  set {
    name  = "clusterAgent.replicas"
    value = "1"
  }

  set {
    name  = "clusterAgent.admissionController.enabled"
    value = "false"
  }

  depends_on = [
    azurerm_kubernetes_cluster.prod_aks,
    azurerm_kubernetes_cluster_node_pool.prod,
    kubernetes_secret.datadog_api_key
  ]
}


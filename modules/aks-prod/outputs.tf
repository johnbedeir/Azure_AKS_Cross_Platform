####################################################################################################
###                                                                                              ###
###                                      AKS MODULE OUTPUTS                                      ###
###                                                                                              ###
####################################################################################################

output "cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.prod_aks.name
}

output "cluster_endpoint" {
  description = "Endpoint for the AKS cluster API server"
  value       = azurerm_kubernetes_cluster.prod_aks.fqdn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = azurerm_kubernetes_cluster.prod_aks.kube_config.0.cluster_ca_certificate
}

output "resource_group_name" {
  description = "Resource group name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.prod_aks.resource_group_name
}


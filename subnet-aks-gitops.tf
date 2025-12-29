####################################################################################################
###                                                                                              ###
###                            AKS GitOps Management Subnet Definitions                          ###
###                                                                                              ###
####################################################################################################

# Create dedicated AKS GitOps subnets for ArgoCD and ChartMuseum management
# Using for_each to create subnets from list variable

locals {
  # Map availability zones to subnet indices (2 AZs for high availability)
  aks_gitops_azs = [
    var.az_primary,
    var.az_secondary
  ]

  # Get the actual GitOps cluster name - constructed from name_prefix and environment
  # This matches the cluster name format used in the AKS module: ${name_prefix}-${environment}
  gitops_cluster_name = "${var.gitops_name_prefix}-${var.gitops_environment}"
}

resource "azurerm_subnet" "private_aks_gitops" {
  for_each = {
    for idx, cidr in var.private_aks_gitops_subnets : idx => {
      cidr = cidr
    }
  }

  name                 = "private-aks-gitops-subnet-${var.name_region}-${format("%02d", each.key)}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [each.value.cidr]

  # Note: Subnet delegation is NOT required for AKS node pools
  # Delegation is only needed for certain advanced scenarios
  # Default node pools cannot use delegated subnets, so we keep subnets non-delegated
}

####################################################################################################
###                                                                                              ###
###                                       Outputs                                               ###
###                                                                                              ###
####################################################################################################

# Output subnet IDs for use in AKS GitOps configuration
output "aks_gitops_subnet_ids" {
  description = "List of AKS GitOps subnet IDs"
  value       = [for subnet in azurerm_subnet.private_aks_gitops : subnet.id]
}

output "aks_gitops_subnet_cidrs" {
  description = "List of AKS GitOps subnet CIDRs"
  value       = [for subnet in azurerm_subnet.private_aks_gitops : subnet.address_prefixes[0]]
}


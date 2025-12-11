####################################################################################################
###                                                                                              ###
###                            AKS Production Subnet Definitions                                 ###
###                                                                                              ###
####################################################################################################

# Create dedicated AKS production subnets for application deployment
# Using for_each to create subnets from list variable

locals {
  # Map availability zones to subnet indices (2 AZs for high availability)
  aks_prod_azs = [
    var.az_primary,
    var.az_secondary
  ]
}

resource "azurerm_subnet" "private_aks_prod" {
  for_each = {
    for idx, cidr in var.private_aks_prod_subnets : idx => {
      cidr = cidr
    }
  }

  name                 = "private-aks-prod-subnet-${var.name_region}-${format("%02d", each.key)}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [each.value.cidr]
}

####################################################################################################
###                                                                                              ###
###                                       Outputs                                               ###
###                                                                                              ###
####################################################################################################

# Output subnet IDs for use in AKS configuration
output "aks_prod_subnet_ids" {
  description = "List of AKS production subnet IDs"
  value       = [for subnet in azurerm_subnet.private_aks_prod : subnet.id]
}

output "aks_prod_subnet_cidrs" {
  description = "List of AKS production subnet CIDRs"
  value       = [for subnet in azurerm_subnet.private_aks_prod : subnet.address_prefixes[0]]
}


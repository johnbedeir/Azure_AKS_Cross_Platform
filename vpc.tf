####################################################################################################
###                                                                                              ###
###                                    Virtual Network Configuration                             ###
###                                                                                              ###
####################################################################################################

# Create resource group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.region

  tags = {
    Budget = var.networking_budget
    Env    = var.env_tag
  }
}

# Create Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "aks-vnet-${var.name_region}"
  address_space       = [var.vpc_cidr]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    Name   = "aks-vnet-${var.name_region}"
    Budget = var.networking_budget
    Env    = var.env_tag
  }
}

# Note: Azure uses Network Security Groups (NSGs) instead of Network ACLs
# Firewall rules are defined in the modules/networking.tf files


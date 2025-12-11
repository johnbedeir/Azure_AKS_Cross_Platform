####################################################################################################
###                                                                                              ###
###                                   AKS NETWORKING                                             ###
###                                                                                              ###
####################################################################################################

# Azure uses Network Security Groups (NSGs) for firewall rules
# This file defines NSG rules for the AKS cluster

# Network Security Group for AKS nodes
resource "azurerm_network_security_group" "aks_nodes" {
  name                = "${local.cluster_name}-nodes-nsg"
  location            = var.region
  resource_group_name = var.resource_group_name

  tags = {
    Name   = "${local.cluster_name}-nodes-nsg"
    Budget = var.proc_budget
    Env    = var.environment
  }
}

# Allow inbound HTTPS from VNet
resource "azurerm_network_security_rule" "aks_nodes_https" {
  name                        = "AllowHTTPS"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = var.network_cidr
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.aks_nodes.name
}

# Allow inbound from cluster API server
resource "azurerm_network_security_rule" "aks_nodes_cluster" {
  name                        = "AllowClusterAPI"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "10250"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.aks_nodes.name
}

# Allow all outbound traffic
resource "azurerm_network_security_rule" "aks_nodes_egress" {
  name                        = "AllowAllOutbound"
  priority                    = 1000
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.aks_nodes.name
}

# Associate NSG with subnets
# Using count instead of for_each since subnet_ids are unknown at plan time
resource "azurerm_subnet_network_security_group_association" "aks_nodes" {
  count = length(var.subnet_ids)

  subnet_id                 = var.subnet_ids[count.index]
  network_security_group_id = azurerm_network_security_group.aks_nodes.id
}


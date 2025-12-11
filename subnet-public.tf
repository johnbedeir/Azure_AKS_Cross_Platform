####################################################################################################
###                                                                                              ###
###                            Public Subnet Definitions                                          ###
###                                                                                              ###
####################################################################################################

# Create public subnets for NAT Gateway and Load Balancers
# These are needed for outbound internet access from private subnets
# Using for_each to create subnets from list variable

locals {
  # Map availability zones to subnet indices
  public_azs = [
    var.az_primary,
    var.az_secondary
  ]
}

resource "azurerm_subnet" "public" {
  for_each = {
    for idx, cidr in var.public_subnets : idx => {
      cidr = cidr
    }
  }

  name                 = "public-subnet-${var.name_region}-${format("%02d", each.key)}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name  = azurerm_virtual_network.main.name
  address_prefixes     = [each.value.cidr]
}

####################################################################################################
###                                                                                              ###
###                            NAT Gateway                                                        ###
###                                                                                              ###
####################################################################################################

# Public IP for NAT Gateway
resource "azurerm_public_ip" "nat_gateway" {
  name                = "nat-gateway-ip-${var.name_region}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Name   = "nat-gateway-ip-${var.name_region}"
    Budget = var.networking_budget
  }
}

# NAT Gateway (single NAT Gateway for cost efficiency)
# Private subnets route through this for internet access
resource "azurerm_nat_gateway" "main" {
  name                    = "nat-gateway-${var.name_region}"
  location                = azurerm_resource_group.main.location
  resource_group_name     = azurerm_resource_group.main.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 4

  tags = {
    Name   = "nat-gateway-${var.name_region}"
    Budget = var.networking_budget
  }
}

# Associate NAT Gateway with public IP
resource "azurerm_nat_gateway_public_ip_association" "main" {
  nat_gateway_id       = azurerm_nat_gateway.main.id
  public_ip_address_id = azurerm_public_ip.nat_gateway.id
}

# Associate NAT Gateway with public subnets
resource "azurerm_subnet_nat_gateway_association" "public" {
  for_each = azurerm_subnet.public

  subnet_id      = each.value.id
  nat_gateway_id = azurerm_nat_gateway.main.id
}

####################################################################################################
###                                                                                              ###
###                            Route Table for Private Subnets                                    ###
###                                                                                              ###
####################################################################################################

# Route table for private subnets to route through NAT Gateway
resource "azurerm_route_table" "private" {
  name                = "private-route-table-${var.name_region}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  route {
    name           = "default-route"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "Internet"
  }

  tags = {
    Name   = "private-route-table-${var.name_region}"
    Budget = var.networking_budget
  }
}

# Associate route table with AKS production subnets
resource "azurerm_subnet_route_table_association" "aks_prod" {
  for_each = azurerm_subnet.private_aks_prod

  subnet_id      = each.value.id
  route_table_id = azurerm_route_table.private.id
}

# Associate route table with AKS GitOps subnets
resource "azurerm_subnet_route_table_association" "aks_gitops" {
  for_each = azurerm_subnet.private_aks_gitops

  subnet_id      = each.value.id
  route_table_id = azurerm_route_table.private.id
}

####################################################################################################
###                                                                                              ###
###                                       Outputs                                               ###
###                                                                                              ###
####################################################################################################

# Output public subnet IDs
output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = [for subnet in azurerm_subnet.public : subnet.id]
}

# Output public subnet CIDRs
output "public_subnet_cidrs" {
  description = "List of public subnet CIDRs"
  value       = [for subnet in azurerm_subnet.public : subnet.address_prefixes[0]]
}


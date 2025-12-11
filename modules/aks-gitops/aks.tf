####################################################################################################
###                                                                                              ###
###                                       AKS CLUSTER                                            ###
###                                                                                              ###
####################################################################################################

locals {
  cluster_name = "${var.name_prefix}-${var.environment}"
}

# Get current Azure client config for authentication
data "azurerm_client_config" "current" {}

# Provider configuration for this cluster
# Using kube_config credentials (works when azure_rbac_enabled is false)
provider "kubernetes" {
  alias                  = "gitops"
  host                   = azurerm_kubernetes_cluster.gitops_aks.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.gitops_aks.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.gitops_aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.gitops_aks.kube_config.0.cluster_ca_certificate)
}

provider "helm" {
  alias = "gitops"
  kubernetes {
    host                   = azurerm_kubernetes_cluster.gitops_aks.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.gitops_aks.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.gitops_aks.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.gitops_aks.kube_config.0.cluster_ca_certificate)
  }
}

resource "azurerm_kubernetes_cluster" "gitops_aks" {
  name                = local.cluster_name
  location            = var.region
  resource_group_name = var.resource_group_name
  dns_prefix          = local.cluster_name
  kubernetes_version  = var.aks_version

  # Enable private cluster
  private_cluster_enabled = false

  # Network configuration
  network_profile {
    network_plugin     = "azure"
    network_policy     = "azure"
    service_cidr       = cidrsubnet(var.network_cidr, 4, 14) # Use a different /20 from the VNet
    dns_service_ip     = cidrhost(cidrsubnet(var.network_cidr, 4, 14), 10)
    docker_bridge_cidr = "172.17.0.1/16"
  }

  # Default node pool (will be removed after custom pool is created)
  default_node_pool {
    name                = "default"
    node_count          = 1
    vm_size             = "Standard_D2s_v3"
    enable_auto_scaling = false
    type                = "VirtualMachineScaleSets"
    vnet_subnet_id      = var.subnet_ids[0]
    os_disk_type        = "Managed"
    os_disk_size_gb     = 30
  }

  # Service principal for AKS
  identity {
    type = "SystemAssigned"
  }

  # Role-based access control
  role_based_access_control_enabled = true

  # Azure Active Directory integration
  # Note: azure_rbac_enabled is set to false to allow Terraform to use kube_config credentials
  # Azure AD is still enabled (managed = true) for user authentication via kubectl
  azure_active_directory_role_based_access_control {
    managed                = true
    azure_rbac_enabled     = false
    admin_group_object_ids = var.admin_users
  }

  # Note: Addons are now managed separately or have been deprecated
  # http_application_routing, kube_dashboard, and oms_agent are no longer part of addon_profile
  # Use Azure Monitor for containers or other monitoring solutions instead

  # Tags
  tags = {
    Budget = var.proc_budget
    Env    = var.environment
  }

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count
    ]
  }
}


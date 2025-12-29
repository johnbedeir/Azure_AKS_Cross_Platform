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
# Using exec with kubelogin - works with Azure AD enabled clusters
# Requires: kubelogin installed and Azure CLI authenticated
provider "kubernetes" {
  alias = "gitops"
  host  = azurerm_kubernetes_cluster.gitops_aks.kube_config.0.host

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "kubelogin"
    args        = ["get-token", "--login", "azurecli", "--server-id", "6dae42f8-4368-4678-94ff-3960e8e3c3d0"]
  }

  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.gitops_aks.kube_config.0.cluster_ca_certificate)
}

provider "helm" {
  alias = "gitops"
  kubernetes {
    host = azurerm_kubernetes_cluster.gitops_aks.kube_config.0.host

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "kubelogin"
      args        = ["get-token", "--login", "azurecli", "--server-id", "6dae42f8-4368-4678-94ff-3960e8e3c3d0"]
    }

    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.gitops_aks.kube_config.0.cluster_ca_certificate)
  }
}

resource "azurerm_kubernetes_cluster" "gitops_aks" {
  name                = local.cluster_name
  location            = var.region
  resource_group_name = var.resource_group_name
  dns_prefix          = local.cluster_name
  kubernetes_version  = var.aks_version

  # Public cluster with nodes in private subnets
  # API server has public IP but nodes run in private subnets for security
  private_cluster_enabled = false

  # API server authorized IP ranges - allow access from anywhere (0.0.0.0/0)
  # This makes the cluster API server accessible from the internet
  api_server_authorized_ip_ranges = ["0.0.0.0/0"]

  # Network configuration
  network_profile {
    network_plugin     = "azure"
    network_policy     = "azure"
    service_cidr       = cidrsubnet(var.network_cidr, 4, 14) # Use a different /20 from the VNet
    dns_service_ip     = cidrhost(cidrsubnet(var.network_cidr, 4, 14), 10)
    docker_bridge_cidr = "172.17.0.1/16"
    # Load balancer will use public subnets for internet-facing services
    load_balancer_sku = "standard"
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

  # Role-based access control (without Azure AD for simplicity)
  role_based_access_control_enabled = true

  # Note: Azure AD is disabled to simplify authentication
  # Use kube_config credentials directly without kubelogin

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


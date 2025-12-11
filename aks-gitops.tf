####################################################################################################
###                                                                                              ###
###                                    AKS GitOps Module                                          ###
###                                                                                              ###
####################################################################################################

# Call the AKS GitOps module using the new subnets from subnet_aks_gitops.tf
module "aks_gitops" {
  source = "./modules/aks-gitops"

  # General
  name_prefix  = var.gitops_name_prefix
  environment  = var.gitops_environment
  cluster_name = var.gitops_cluster_name
  aks_version  = var.gitops_aks_version

  # Azure account
  region              = var.region
  subscription_id     = var.subscription_id
  tenant_id           = var.tenant_id
  resource_group_name = azurerm_resource_group.main.name

  # Networking
  network_cidr = var.vpc_cidr
  vnet_name    = azurerm_virtual_network.main.name
  # CRITICAL: Node subnets MUST match the subnets used for AKS
  # AKS requires subnets with proper delegation
  subnet_ids = [
    for subnet in azurerm_subnet.private_aks_gitops : subnet.id
  ]

  # Public subnets for internet-facing LoadBalancers (ArgoCD, Chartmuseum)
  public_subnet_ids = [
    for subnet in azurerm_subnet.public : subnet.id
  ]

  # Node pool - smaller instances for GitOps management
  node_pool_vm_size      = var.gitops_node_pool_vm_size
  node_pool_desired_size = var.gitops_node_pool_desired_size
  node_pool_min_size     = var.gitops_node_pool_min_size
  node_pool_max_size     = var.gitops_node_pool_max_size

  # Auth - same admin users as production
  admin_users = var.gitops_admin_users

  # Tags
  proc_budget = var.proc_budget

  # Datadog
  datadog_api_secret_name = var.gitops_datadog_api_secret_name
  key_vault_id            = azurerm_key_vault.main.id
  # NOTE: Secrets must be created first. They are created in secrets.tf at the root level.

  # Cross-cluster communication
  target_cluster_name           = module.aks.cluster_name
  target_cluster_endpoint       = module.aks.cluster_endpoint
  target_cluster_ca_data        = module.aks.cluster_certificate_authority_data
  target_cluster_resource_group = azurerm_resource_group.main.name

  # Enable GitOps-specific components
  enable_rbac_config        = true
  enable_datadog            = true
  enable_cluster_autoscaler = true
  enable_chartmuseum        = true
  enable_argocd             = true
}


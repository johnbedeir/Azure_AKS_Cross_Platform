####################################################################################################
###                                                                                              ###
###                                       AKS MODULE                                             ###
###                                                                                              ###
####################################################################################################

# Call the AKS module using the existing subnets from subnet-aks.tf
module "aks" {
  source = "./modules/aks-prod"

  # General
  name_prefix  = var.name_prefix
  environment  = var.environment
  cluster_name = var.cluster_name
  aks_version  = var.aks_version

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
    for subnet in azurerm_subnet.private_aks_prod : subnet.id
  ]

  # Node pool (blue-green migration support)
  node_pool_new_vm_size      = var.node_pool_new_vm_size
  node_pool_new_desired_size = var.node_pool_new_desired_size
  node_pool_new_min_size     = var.node_pool_new_min_size
  node_pool_new_max_size     = var.node_pool_new_max_size

  # Auth
  admin_users = var.admin_users

  # Tags
  proc_budget = var.proc_budget

  # Datadog
  datadog_api_secret_name = var.datadog_api_secret_name
  key_vault_id            = azurerm_key_vault.main.id
  # NOTE: Secrets must be created first. They are created in secrets.tf at the root level.

  # ArgoCD GitOps access
  # Pass the actual cluster name that matches the GitOps module's var.cluster_name
  # The GitOps module constructs cluster name as: ${name_prefix}-${environment}
  enable_argocd_access = true
  gitops_cluster_name  = "${var.gitops_name_prefix}-${var.gitops_environment}"

  # Enable optional components
  enable_rbac_config        = false # Disabled - not needed for basic setup
  enable_datadog            = false # Disabled - can enable later if needed
  enable_cluster_autoscaler = true  # Keep enabled for auto-scaling
}


####################################################################################################
###                                                                                              ###
###                                     AKS MODULE VARIABLES                                     ###
###                                                                                              ###
####################################################################################################

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "cluster_name" {
  description = "AKS cluster name"
  type        = string
}

variable "aks_version" {
  description = "Kubernetes version for the AKS cluster"
  type        = string
}

variable "region" {
  description = "Azure region (used by autoscaler and other components)"
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
}

variable "network_cidr" {
  description = "CIDR block of the VNet (used for network security group rules)"
  type        = string
}

# Blue-Green Node Pool Variables
variable "node_pool_new_vm_size" {
  description = "VM sizes for the new node pool (blue-green migration)"
  type        = list(string)
  default     = []
}

variable "node_pool_new_desired_size" {
  description = "Desired number of nodes in the new node pool"
  type        = number
  default     = 0
}

variable "node_pool_new_min_size" {
  description = "Minimum number of nodes in the new node pool"
  type        = number
  default     = 0
}

variable "node_pool_new_max_size" {
  description = "Maximum number of nodes in the new node pool"
  type        = number
  default     = 25
}

variable "admin_users" {
  description = "Azure AD object IDs or user principal names to grant cluster-admin access (system:masters)"
  type        = list(string)
  default     = []
}

variable "proc_budget" {
  description = "Budget tag value to apply across AKS resources"
  type        = string
}

variable "key_vault_id" {
  description = "ID of the Azure Key Vault containing secrets"
  type        = string
  default     = ""
}

variable "enable_argocd_access" {
  description = "Enable ArgoCD access from GitOps cluster"
  type        = bool
  default     = false
}

variable "gitops_cluster_name" {
  description = "Name of the GitOps cluster for ArgoCD access"
  type        = string
  default     = ""
}

variable "enable_rbac_config" {
  description = "Whether to manage RBAC configuration via Terraform"
  type        = bool
  default     = false
}

variable "enable_metrics_server" {
  description = "Whether to install Metrics Server via Helm"
  type        = bool
  default     = false
}

variable "enable_cluster_autoscaler" {
  description = "Whether to enable Cluster Autoscaler (AKS native)"
  type        = bool
  default     = false
}

variable "vnet_name" {
  description = "Virtual network name where AKS resources are created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the AKS control plane and node pools"
  type        = list(string)
}


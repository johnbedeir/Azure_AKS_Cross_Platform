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

variable "node_pool_vm_size" {
  description = "VM sizes for the node pool"
  type        = list(string)
}

variable "node_pool_desired_size" {
  description = "Desired number of nodes in the node pool"
  type        = number
}

variable "node_pool_min_size" {
  description = "Minimum number of nodes in the node pool"
  type        = number
}

variable "node_pool_max_size" {
  description = "Maximum number of nodes in the node pool"
  type        = number
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

variable "enable_chartmuseum" {
  description = "Whether to install ChartMuseum via Helm"
  type        = bool
  default     = false
}

variable "chartmuseum_storage_size" {
  description = "Size of the persistent volume for ChartMuseum storage"
  type        = string
  default     = "8Gi"
}

variable "chartmuseum_storage_class" {
  description = "Storage class for ChartMuseum persistent volume"
  type        = string
  default     = "managed-csi"
}

variable "enable_argocd" {
  description = "Whether to install ArgoCD via Helm"
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

variable "public_subnet_ids" {
  description = "List of public subnet IDs for internet-facing LoadBalancers"
  type        = list(string)
  default     = []
}

# Cross-cluster communication variables
variable "target_cluster_name" {
  description = "Name of the target cluster that this GitOps cluster will manage"
  type        = string
  default     = ""
}

variable "target_cluster_endpoint" {
  description = "Endpoint of the target cluster for cross-cluster communication"
  type        = string
  default     = ""
}

variable "target_cluster_ca_data" {
  description = "Certificate authority data of the target cluster"
  type        = string
  default     = ""
}

variable "target_cluster_resource_group" {
  description = "Resource group name of the target cluster"
  type        = string
  default     = ""
}


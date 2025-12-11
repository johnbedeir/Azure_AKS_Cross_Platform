###
# Declare all variables, without values, environment specific values are loaded later.
###

###
# Region related settings.
###

variable "subscription_id" {
  description = "The Azure subscription ID."
  type        = string
}

variable "tenant_id" {
  description = "The Azure tenant ID."
  type        = string
}

variable "region" {
  description = "The Azure region to work in."
  type        = string
}

variable "az_primary" {
  description = "The primary availability zone to use."
  type        = string
}

variable "az_secondary" {
  description = "The secondary availability zone to use."
  type        = string
}

###
# IP settings. (ranges)
###

variable "vpc_cidr" {
  description = "VNet IP Range in CIDR notation."
  type        = string
}

###
# Budget tag values.
###

variable "networking_budget" {
  description = "Value for the Budget tag for networking resources."
  type        = string
}

variable "proc_budget" {
  description = "Value for the Budget tag for processing resources."
  type        = string
}

###
# Other tag values
###

variable "env_tag" {
  description = "Value of the env tag, probably 'prod' or 'dev'."
  type        = string
}

variable "replicated_region" {
  description = "The Azure region used for replication."
  type        = string
}

###
# Things that make other things pretty.
###

variable "name_region" {
  description = "The name of the region. Used to name things. eg: us-east-1"
  type        = string
}

####################################################################################################
###                                                                                              ###
###                                       AKS VARIABLES                                          ###
###                                                                                              ###
####################################################################################################

variable "name_prefix" {
  description = "The prefix for the name of the AKS cluster."
  type        = string
}

variable "environment" {
  description = "The environment for the AKS cluster."
  type        = string
}

variable "admin_users" {
  type        = list(string)
  description = "List of Kubernetes admins (Azure AD object IDs or user principal names)."
}

variable "aks_version" {
  description = "The version of the AKS cluster."
  type        = string
}

# Blue-Green Node Pool Variables
variable "node_pool_new_vm_size" {
  description = "VM sizes for the new node pool (blue-green migration)"
  type        = list(string)
}

variable "node_pool_new_desired_size" {
  description = "Desired number of nodes in the new node pool"
  type        = number
}

variable "node_pool_new_min_size" {
  description = "Minimum number of nodes in the new node pool"
  type        = number
}

variable "node_pool_new_max_size" {
  description = "Maximum number of nodes in the new node pool"
  type        = number
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "datadog_api_secret_name" {
  description = "The name of the Datadog API key secret in Azure Key Vault."
  type        = string
}

variable "datadog_api_key_value" {
  description = "The Datadog API key value (will be stored in Azure Key Vault)."
  type        = string
  sensitive   = true
}

# GitOps AKS Cluster Variables
variable "gitops_name_prefix" {
  description = "Name prefix for the GitOps AKS cluster"
  type        = string
}

variable "gitops_environment" {
  description = "Environment name for the GitOps AKS cluster"
  type        = string
}

variable "gitops_cluster_name" {
  description = "Name of the GitOps AKS cluster"
  type        = string
}

variable "gitops_aks_version" {
  description = "Kubernetes version for the GitOps AKS cluster"
  type        = string
}

variable "gitops_admin_users" {
  description = "List of admin users for the GitOps AKS cluster (Azure AD object IDs or user principal names)"
  type        = list(string)
}

variable "gitops_node_pool_vm_size" {
  description = "VM sizes for the GitOps AKS node pool"
  type        = list(string)
}

variable "gitops_node_pool_desired_size" {
  description = "Desired size of the GitOps AKS node pool"
  type        = number
}

variable "gitops_node_pool_min_size" {
  description = "Minimum size of the GitOps AKS node pool"
  type        = number
}

variable "gitops_node_pool_max_size" {
  description = "Maximum size of the GitOps AKS node pool"
  type        = number
}

variable "gitops_datadog_api_secret_name" {
  description = "The name of the Datadog API key secret for GitOps cluster in Azure Key Vault."
  type        = string
}

variable "gitops_datadog_api_key_value" {
  description = "The Datadog API key value for GitOps cluster (will be stored in Azure Key Vault)."
  type        = string
  sensitive   = true
}

# AKS Production Subnet Variables
variable "private_aks_prod_subnets" {
  description = "List of IP ranges for AKS production subnets in CIDR notation."
  type        = list(string)
}

# AKS GitOps Management Subnet Variables
variable "private_aks_gitops_subnets" {
  description = "List of IP ranges for AKS GitOps management subnets in CIDR notation."
  type        = list(string)
}

# Public Subnet Variables
variable "public_subnets" {
  description = "List of IP ranges for public subnets in CIDR notation."
  type        = list(string)
}

# Resource Group
variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
}


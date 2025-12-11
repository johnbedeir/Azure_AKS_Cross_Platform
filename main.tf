####################################################################################################
###                                                                                              ###
###                                   Terraform  Configuration                                   ###
###                                                                                              ###
####################################################################################################

terraform {
  # Latest version on the registry when I refreshed this.
  # Remember to keep modules up to date with this.
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.37.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11.0"
    }
  }
  # Terraform version requirement - supports 1.5.7 and above
  required_version = ">= 1.5.7"

  # Backend configuration removed for new project
  # To use Azure Storage backend, uncomment and configure:
  # backend "azurerm" {
  #   resource_group_name  = "your-terraform-state-rg"
  #   storage_account_name = "your-terraform-state-storage"
  #   container_name       = "terraform-state"
  #   key                  = "terraform.tfstate"
  # }
}

####################################################################################################
###                                                                                              ###
###                                    Provider Configuration                                    ###
###                                                                                              ###
####################################################################################################

# Configure Azure provider
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

# Configure Azure provider for replication region (if needed)
provider "azurerm" {
  alias = "replication_target"
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

# Kubernetes and Helm providers are configured inside the AKS modules
# This avoids circular dependencies where providers would need data sources
# that depend on modules that need providers

####################################################################################################
###                                                                                              ###
###                                     Misc & Data sources                                      ###
###                                                                                              ###
####################################################################################################

# Get the current Azure subscription
data "azurerm_subscription" "current" {}

# AKS cluster data sources for external access (if needed)
# Note: These are optional and only needed if you want to access clusters from outside the modules
# The modules configure their own providers internally
data "azurerm_kubernetes_cluster" "cluster" {
  name                = module.aks.cluster_name
  resource_group_name = module.aks.resource_group_name

  depends_on = [
    module.aks
  ]
}

data "azurerm_kubernetes_cluster" "gitops_cluster" {
  name                = module.aks_gitops.cluster_name
  resource_group_name = module.aks_gitops.resource_group_name

  depends_on = [
    module.aks_gitops
  ]
}

####################################################################################################
###                                                                                              ###
###                                    AKS-Only Configuration                                    ###
###                                                                                              ###
###  This project is configured for AKS-only deployment. All legacy modules (IAM, CICD,        ###
###  databases, CDN, API clusters, etc.) have been removed. Only AKS production and GitOps     ###
###  clusters are managed by this Terraform configuration.                                      ###
###                                                                                              ###
####################################################################################################


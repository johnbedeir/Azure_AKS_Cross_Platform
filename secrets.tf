####################################################################################################
###                                                                                              ###
###                                    Azure Key Vault Secrets                                    ###
###                                                                                              ###
####################################################################################################

# Create Key Vault for storing secrets
resource "azurerm_key_vault" "main" {
  name                = "kv-${var.name_region}-${random_string.suffix.result}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  enabled_for_deployment          = true
  enabled_for_template_deployment = true
  enabled_for_disk_encryption     = true

  tags = {
    Budget = var.proc_budget
    Env    = var.env_tag
  }
}

# Random string for Key Vault name uniqueness
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

# Grant current user access to Key Vault
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault_access_policy" "current_user" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Recover",
    "Backup",
    "Restore"
  ]
}

# Datadog API Key Secret for AKS Production Cluster
resource "azurerm_key_vault_secret" "datadog_api_key" {
  name         = var.datadog_api_secret_name
  value        = var.datadog_api_key_value
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current_user]

  lifecycle {
    ignore_changes = [value]
  }
}

# Datadog API Key Secret for AKS GitOps Cluster
resource "azurerm_key_vault_secret" "gitops_datadog_api_key" {
  name         = var.gitops_datadog_api_secret_name
  value        = var.gitops_datadog_api_key_value
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current_user]

  lifecycle {
    ignore_changes = [value]
  }
}


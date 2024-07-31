# #############################################################################
# Key Vault
# #############################################################################

resource "azurerm_key_vault" "remanufacturing" {
  name                        = lower("${module.resource_group.name.abbreviation}-CRReman${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}")
  location                    = azurerm_resource_group.remanufacturing.location
  resource_group_name         = azurerm_resource_group.remanufacturing.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = true
  sku_name                    = "standard"
  enable_rbac_authorization  = true
}

resource "azurerm_role_assignment" "key_vault" {
  scope                = azurerm_key_vault.remanufacturing.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}
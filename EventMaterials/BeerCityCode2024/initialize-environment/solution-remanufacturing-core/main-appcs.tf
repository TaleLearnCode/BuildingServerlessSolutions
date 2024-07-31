# #############################################################################
# App Configuration
# #############################################################################

resource "azurerm_app_configuration" "remanufacturing" {
  name                       = "${module.app_config.name.abbreviation}-CoolRevive-Remanufacturing${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  resource_group_name        = azurerm_resource_group.remanufacturing.name
  location                   = azurerm_resource_group.remanufacturing.location
  sku                        = "standard"
  local_auth_enabled         = true
  public_network_access      = "Enabled"
  purge_protection_enabled   = false
  soft_delete_retention_days = 1
  tags = local.tags
}

# Role Assignment: 'App Configuration Data Owner' to current Terraform user
resource "azurerm_role_assignment" "app_configuration" {
  scope                = azurerm_app_configuration.remanufacturing.id
  role_definition_name = "App Configuration Data Owner"
  principal_id         = data.azurerm_client_config.current.object_id
}

## Key Vault Secret: AppConfigurationEndpoint
#resource "azurerm_key_vault_secret" "app_configuration" {
#  name         = "AppConfigurationEndpoint"
#  value        = azurerm_app_configuration.remanufacturing.endpoint
#  key_vault_id = azurerm_key_vault.remanufacturing.id
#}
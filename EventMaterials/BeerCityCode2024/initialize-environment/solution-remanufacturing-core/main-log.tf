# #############################################################################
# Log Analytics Workspace
# #############################################################################

resource "azurerm_log_analytics_workspace" "remanufacturing" {
  name                = "${module.log_analytics_workspace.name.abbreviation}-CoolRevive-Remanufacturing${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  location            = azurerm_resource_group.remanufacturing.location
  resource_group_name = azurerm_resource_group.remanufacturing.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

## Key Vault Secret: Analytics Workspace Key (AnalyticsWorkspaceKey)
#resource "azurerm_key_vault_secret" "log_analytics" {
#  name         = "AnalyticsWorkspaceKey"
#  value        = azurerm_log_analytics_workspace.remanufacturing.primary_shared_key
#  key_vault_id = azurerm_key_vault.remanufacturing.id
#}

## App Configuration Key: Analytics Workspace Key (ConnectionStrings:AnalyticsWorkSpaceKey)
#resource "azurerm_app_configuration_key" "log_analytics_key" {
#  configuration_store_id = azurerm_app_configuration.remanufacturing.id
#  key                    = "ConnectionStrings:AnalyticsWorkSpaceKey"
#  type                   = "vault"
#  label                  = var.azure_environment
#  vault_key_reference    = azurerm_key_vault_secret.log_analytics.versionless_id
#  lifecycle {
#    ignore_changes = [
#      value
#    ]
#  }
#}

## App Configuration Key: Log Analytics Workspace (ConnectionStrings:AnalyticsWorkspaceId)
#resource "azurerm_app_configuration_key" "log_analytics_workspace_id" {
#  configuration_store_id = azurerm_app_configuration.remanufacturing.id
#  key                    = "ConnectionStrings:AnalyticsWorkspaceId"
#  label                  = var.azure_environment
#  value                  = azurerm_log_analytics_workspace.remanufacturing.workspace_id
#}
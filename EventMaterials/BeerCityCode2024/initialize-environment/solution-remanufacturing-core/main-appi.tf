# #############################################################################
# Application Insights: Catalog (appi-catalog)
# #############################################################################

resource "azurerm_application_insights" "remanufacturing" {
  name                = "${module.application_insights.name.abbreviation}-CoolRevive-Remanufacturing${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  location            = azurerm_resource_group.remanufacturing.location
  resource_group_name = azurerm_resource_group.remanufacturing.name
  workspace_id        = azurerm_log_analytics_workspace.remanufacturing.id
  application_type    = "web"
  tags                = local.tags
}

## Key Vault Secret: Instrumentation Key (ai-instrumentation-key)
#resource "azurerm_key_vault_secret" "appinsights" {
#  name         = "AppInsightsInstrumentationKey"
#  value        = azurerm_application_insights.remanufacturing.instrumentation_key
#  key_vault_id = azurerm_key_vault.remanufacturing.id
#}

## App Configuration Key: Application Insights - Connection String (ApplicationInsights:ConnectionString)
#resource "azurerm_app_configuration_key" "appinsights_connection_string" {
#  configuration_store_id = azurerm_app_configuration.remanufacturing.id
#  key                    = "ApplicationInsights:ConnectionString"
#  label                  = var.azure_environment
#  value                  = azurerm_application_insights.remanufacturing.connection_string
#}
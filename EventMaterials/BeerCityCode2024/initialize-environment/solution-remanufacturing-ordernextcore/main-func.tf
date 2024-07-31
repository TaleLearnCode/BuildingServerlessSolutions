# ##############################################################################
# Order Next Core Function App
# ##############################################################################

# ------------------------------------------------------------------------------
# Storage Account
# ------------------------------------------------------------------------------

resource "azurerm_storage_account" "function_storage" {
  name                     = lower("${module.storage_account.name.abbreviation}CRONC${var.resource_name_suffix}${var.azure_environment}${module.azure_regions.region.region_short}")
  resource_group_name      = azurerm_resource_group.order_next_core.name
  location                 = azurerm_resource_group.order_next_core.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.tags
}

# ------------------------------------------------------------------------------
# App Service Plan (server farm)
# ------------------------------------------------------------------------------

resource "azurerm_service_plan" "app_service_plan" {
  name                = "${module.app_service_plan.name.abbreviation}-CoolRevive-OrderNextCore${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  resource_group_name = azurerm_resource_group.order_next_core.name
  location            = azurerm_resource_group.order_next_core.location
  os_type             = "Linux"
  sku_name            = "Y1"
  tags                = local.tags
}

# ------------------------------------------------------------------------------
# Function App
# ------------------------------------------------------------------------------

resource "azurerm_linux_function_app" "function_app" {
  name                       = "${module.function_app.name.abbreviation}-CoolRevive-OrderNextCore${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  resource_group_name        = azurerm_resource_group.order_next_core.name
  location                   = azurerm_resource_group.order_next_core.location
  storage_account_name       = azurerm_storage_account.function_storage.name
  storage_account_access_key = azurerm_storage_account.function_storage.primary_access_key
  service_plan_id            = azurerm_service_plan.app_service_plan.id
  tags                       = local.tags
  

  site_config {
    ftps_state             = "FtpsOnly"
    application_stack {
      dotnet_version              = "8.0"
      use_dotnet_isolated_runtime = true
    }
    application_insights_connection_string = data.azurerm_application_insights.remanufacturing.connection_string
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "AzureWebJobsStorage__accountName" = azurerm_storage_account.function_storage.name,
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = data.azurerm_application_insights.remanufacturing.connection_string
}
  lifecycle {
    ignore_changes = [storage_uses_managed_identity]
  }
}

# ------------------------------------------------------------------------------
# Role Assignments
# ------------------------------------------------------------------------------

resource "azurerm_role_assignment" "key_vault_secrets_user" {
  scope                = data.azurerm_key_vault.remanufacturing.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_function_app.function_app.identity.0.principal_id
}

resource "azurerm_role_assignment" "app_configuration_data_owner" {
  scope                = data.azurerm_app_configuration.remanufacturing.id
  role_definition_name = "App Configuration Data Owner"
  principal_id         = azurerm_linux_function_app.function_app.identity.0.principal_id
}
# #############################################################################
# Cosmos DB
# #############################################################################

resource "azurerm_cosmosdb_account" "inventory_manager" {
  name                = "${module.cosmos_account.name.abbreviation}-CoolRevive-InventoryManager${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  location            = azurerm_resource_group.inventory_manager.location
  resource_group_name = azurerm_resource_group.inventory_manager.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  capabilities {
    name = "EnableServerless"
  }
  consistency_policy {
    consistency_level       = "Session"
    max_interval_in_seconds = 5
    max_staleness_prefix    = 100
  }
  geo_location {
    location          = azurerm_resource_group.inventory_manager.location
    failover_priority = 0
  }
  tags = local.tags
}

resource "azurerm_role_assignment" "search_cosmos" {
  scope                = azurerm_cosmosdb_account.inventory_manager.id
  role_definition_name = "Cosmos DB Account Read/Write"
  principal_id         = azurerm_linux_function_app.function_app.identity[0].principal_id
}

resource "azurerm_cosmosdb_sql_database" "inventory_manager" {
  name                = "inventory-manager"
  resource_group_name = azurerm_cosmosdb_account.inventory_manager.resource_group_name
  account_name        = azurerm_cosmosdb_account.inventory_manager.name
}

resource "azurerm_cosmosdb_sql_container" "inventory_manager" {
  name                  = "inventory-manager-events"
  resource_group_name   = azurerm_cosmosdb_account.inventory_manager.resource_group_name
  account_name          = azurerm_cosmosdb_account.inventory_manager.name
  database_name         = azurerm_cosmosdb_sql_database.inventory_manager.name
  partition_key_paths   = ["/finishedProductId"]
}
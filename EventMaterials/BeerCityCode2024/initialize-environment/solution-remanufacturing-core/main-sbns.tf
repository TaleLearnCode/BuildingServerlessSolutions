# #############################################################################
# Service Bus Namespace
# #############################################################################

resource "azurerm_servicebus_namespace" "remanufacturing" {
  name                = "${module.service_bus_namespace.name.abbreviation}-CoolRevive-Remanufacturing${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  location            = azurerm_resource_group.remanufacturing.location
  resource_group_name = azurerm_resource_group.remanufacturing.name
  sku                 = "Standard"

  tags = {
    source = "terraform"
  }
}
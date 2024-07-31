# #############################################################################
# Service Bus Topic: Get Next Core
# #############################################################################

resource "azurerm_servicebus_topic" "GetNextCore" {
  name                      = "${module.service_bus_topic.name.abbreviation}-CoolRevive-GetNextCore${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  namespace_id              = data.azurerm_servicebus_namespace.remanufacturing.id
  support_ordering          = true
}

resource "azurerm_servicebus_subscription" "GetNextCore" {
  name                                      = "${module.service_bus_topic_subscription.name.abbreviation}-CoolRevive-GetNextCore${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  topic_id                                  = azurerm_servicebus_topic.GetNextCore.id
  dead_lettering_on_filter_evaluation_error = false
  dead_lettering_on_message_expiration      = true
  max_delivery_count                        = 10
  depends_on = [
    azurerm_servicebus_topic.GetNextCore,
  ]
}
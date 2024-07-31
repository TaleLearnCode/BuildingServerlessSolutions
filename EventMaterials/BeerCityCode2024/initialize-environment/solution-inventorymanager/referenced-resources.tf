# #############################################################################
# Referenced resources
# #############################################################################

locals {
  remanufacturing_resource_group_name = "${module.resource_group.name.abbreviation}-CoolRevive-Remanufacturing-${var.azure_environment}-${module.azure_regions.region.region_short}"
}

data "azurerm_key_vault" "remanufacturing" {
  name                = lower("${module.resource_group.name.abbreviation}-CRReman${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}")
  resource_group_name = local.remanufacturing_resource_group_name
}

data "azurerm_app_configuration" "remanufacturing" {
  name                = "${module.app_config.name.abbreviation}-CoolRevive-Remanufacturing${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  resource_group_name = local.remanufacturing_resource_group_name
}

data "azurerm_application_insights" "remanufacturing" {
  name                = "${module.application_insights.name.abbreviation}-CoolRevive-Remanufacturing${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  resource_group_name = local.remanufacturing_resource_group_name
}

data "azurerm_servicebus_namespace" "remanufacturing" {
  name                = "${module.service_bus_namespace.name.abbreviation}-CoolRevive-Remanufacturing${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  resource_group_name = local.remanufacturing_resource_group_name
}

data "azurerm_servicebus_topic" "order_next_core" {
  name         = "${module.service_bus_topic.name.abbreviation}-CoolRevive-OrderNextCore${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  namespace_id = data.azurerm_servicebus_namespace.remanufacturing.id
}
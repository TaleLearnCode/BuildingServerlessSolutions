# #############################################################################
# Resource Group
# #############################################################################

resource "azurerm_resource_group" "inventory_manager" {
  name     = "${module.resource_group.name.abbreviation}-CoolRevive-Remanufacturing-InventoryManager-${var.azure_environment}-${module.azure_regions.region.region_short}"
  location = module.azure_regions.region.region_cli
  tags     = local.tags
}
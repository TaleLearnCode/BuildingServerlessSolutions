# #############################################################################
# Resource Group
# #############################################################################

resource "azurerm_resource_group" "remanufacturing" {
  name     = "${module.resource_group.name.abbreviation}-CoolRevive-Remanufacturing-${var.azure_environment}-${module.azure_regions.region.region_short}"
  location = module.azure_regions.region.region_cli
  tags     = local.tags
}
# -----------------------------------------------------------------------------
# API Management
# -----------------------------------------------------------------------------

variable "apim_publisher_name" {
  type        = string
  description = "The name of the publisher of the API Management instance."
}

variable "apim_publisher_email" {
  type        = string
  description = "The email address of the publisher of the API Management instance."
}

variable "apim_sku_name" {
  type        = string
  description = "The SKU of the API Management instance."
}

resource "azurerm_api_management" "global" {
  name                = lower("${module.api_management.name.abbreviation}-CoolRevive${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}")
  location            = azurerm_resource_group.global.location
  resource_group_name = azurerm_resource_group.global.name
  publisher_name      = var.apim_publisher_name
  publisher_email     = var.apim_publisher_email
  sku_name            = var.apim_sku_name
  tags                = local.tags
}
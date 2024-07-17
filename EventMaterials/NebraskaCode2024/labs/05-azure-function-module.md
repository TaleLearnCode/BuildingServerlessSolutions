[Design and Develop a Serverless Event-Driven Microservice-Based Solution](https://github.com/TaleLearnCode/EDAMicroserviceWorkshop) \ [Nebraska.Code 2024](README.md)  \ [Labs](README.md) \

# Lab 5: Create Terraform Module for Azure Functions

## Objective

Managing an Azure Function with Terraform requires several configuration elements. An App Service Plan, Azure Storage account, and the Azure Function app must be created. If you want to use virtual network integration with Azure Functions, quite a bit more must be configured (we will not use) virtual networking in this workshop). If you need to create multiple Azure Function apps (such as we will in this workshop), this means a lot of boilerplate and duplicated configuration.

To ease this for the Cool Revive DevOps team, we will create a custom module that will encapsulate the configuration and can be used each time we need to create a Consumption Azure Function.

## Prerequisites

- Completion of [Lab 4](04-create-core-azure-resources.md).
- Terraform is installed on your local machine.
- Azure CLI installed and authenticated on your local machine

## Steps

### Step 1: Create the feature branch

1. If not already done, open a Terminal window in Visual Studio Code (this step does not have to be done within Visual Studio Code).
2. Check out the `develop` branch:

```sh
git checkout develop
```

3. Pull the latest changes:

```sh
git pull
```

4. Create the branch for the lab:

```sh
git branch features/05-azure-function-module
```

5. Checkout the feature branch for the lab:

```sh
git checkout features/05-azure-function-module
```

### Step 2: Create the folder for the module

1. Create the `infra\modules` folder.
2. Create the `infra\modules\function-consumption` folder.

### Step 3: Create the variables file

1. In the `infra\modules\function-consumption` folder, create a file named `variables.tf`, and add the following configuration:

```HCL
variable "app_configuration_id" {
  type        = string
  default     = null
  description = "The ID of the App Configuration."
}

variable "app_insights_connection_string" {
  type        = string
  description = "The Application Insights connection string."
}

variable "app_settings" {
  description = "A map of additional app settings to configure for the Function App"
  type        = map(string)
  default     = {}
}

variable "azure_environment" {
	type        = string
	description = "The environment component of an Azure resource name."
}

variable "azure_region" {
	type        = string
	description = "Location of the resource group."
}

variable "function_app_name" {
  type        = string
  description = "The name of the Function App."
}

variable "key_vault_id" {
  type        = string
  default     = null
  description = "The ID of the Key Vault."
}

variable "resource_group_name" {
  type        = string
  description = "The base name of the resource group."
}

variable "resource_name_suffix" {
  type        = string
  description = "The suffix to append to the resource names."
}

variable "storage_account_name" {
  type        = string
  description = "The name of the Storage Account."
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to assign to the resources."
}
```

### Step 4: Create the modules file

1. In the `infra\modules\function-consumption` folder, create a file named `modules.tf`, and add the following configuration:

```HCL
module "azure_regions" {
  source       = "git::https://github.com/TaleLearnCode/terraform-azure-regions.git"
  azure_region = var.azure_region
}

module "app_service_plan" {
  source = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "app-service-plan"
}

module "function_app" {
  source = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "function-app"
}

module "storage_account" {
  source        = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "storage-account"
}
```

### Step 5: Create the main file

1. In the `infra\modules\function-consumption` folder, create a file named `main.tf`, and add the following configuration:

```HCL
# #############################################################################
# Required Providers
# #############################################################################

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
    }
  }
}

# #############################################################################
# Referenced Resources
# #############################################################################

data "azurerm_resource_group" "function_app_rg" {
  name = var.resource_group_name
}

# #############################################################################
# Storage Account
# #############################################################################

resource "azurerm_storage_account" "function_storage" {
  name                     = lower("${module.storage_account.name.abbreviation}${var.storage_account_name}${var.resource_name_suffix}${var.azure_environment}${module.azure_regions.region.region_short}")
  resource_group_name      = data.azurerm_resource_group.function_app_rg.name
  location                 = data.azurerm_resource_group.function_app_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.tags
}

# #############################################################################
# App Service Plan (server farm)
# #############################################################################

resource "azurerm_service_plan" "app_service_plan" {
  name                = "${module.app_service_plan.name.abbreviation}-${var.function_app_name}${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  resource_group_name = data.azurerm_resource_group.function_app_rg.name
  location            = data.azurerm_resource_group.function_app_rg.location
  os_type             = "Linux"
  sku_name            = "Y1"
  tags                = var.tags
}

# #############################################################################
# Function App
# #############################################################################

resource "azurerm_linux_function_app" "function_app" {
  name                       = "${module.function_app.name.abbreviation}-${var.function_app_name}${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  resource_group_name        = data.azurerm_resource_group.function_app_rg.name
  location                   = data.azurerm_resource_group.function_app_rg.location
  storage_account_name       = azurerm_storage_account.function_storage.name
  storage_account_access_key = azurerm_storage_account.function_storage.primary_access_key
  service_plan_id            = azurerm_service_plan.app_service_plan.id
  tags                       = var.tags
  

  site_config {
    ftps_state             = "FtpsOnly"
    application_stack {
      dotnet_version              = "8.0"
      use_dotnet_isolated_runtime = true
    }
    application_insights_connection_string = var.app_insights_connection_string
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = merge({
    "AzureWebJobsStorage__accountName" = azurerm_storage_account.function_storage.name,
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = var.app_insights_connection_string
  }, var.app_settings)
  lifecycle {
    ignore_changes = [storage_uses_managed_identity]
  }
}

# #############################################################################
# Role Assignments
# #############################################################################

resource "azurerm_role_assignment" "key_vault_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_function_app.function_app.identity.0.principal_id
}

resource "azurerm_role_assignment" "app_configuration_data_owner" {
  scope                = var.app_configuration_id
  role_definition_name = "App Configuration Data Owner"
  principal_id         = azurerm_linux_function_app.function_app.identity.0.principal_id
}
```

In this file, we have the following configuration elements:

- **Required Providers**: This instructs projects using this module what Terraform providers the module requires. For this module, we require `azurerm` (Azure).
- **Referenced Resources**: Defines the resources for which we need data references. For this module, we have:
  - The resource group where we will create the Azure Function resources.
- **Storage Account**: This defines the Azure Storage account that the Azure Function App uses.
- **App Service Plan**: Defines the Azure App Service Plan that hosts the Azure Function App.
- **Function App**: We are creating the Azure Function app using the `azurerm`provider. Note that we can add application settings dynamically.
- **Role Assignments**: Finally, we have the section to create the necessary role assignments for the Azure Function needs. The `Key Vault Secret User` and `App Configuration Data Owner` roles will only be assigned if the corresponding scope resource identifier is provided. Any additional role assignments will be made in the root Terraform project.

### Step 6: Create the output file

One of the nice parts of Terraform modules is that we can pass information back to the primary Terraform project. These are done using the `output` Terraform element.

1. In the `infra\modules\function-consumption` folder, create a file named `outputs.tf`, and add the following configuration:

```HCL
output "function_app_name" {
  value = azurerm_linux_function_app.function_app.name
}
```

In this module, we return the name of the newly created Azure Function App.

### Step 7: Commit and push the Terraform project to your central Git repository

1. Click on the `Source Control` tab within Visual Studio code.
2. Add an appropriate commit message:

```
Adding the Consumption Azure Function module.
```

3. Click the **Commit** button (this will perform a `git commit` command).
4. Click the **Publish Branch** button.

### Step 8: Create a pull request and merge it into develop

#### Using GitHub

1. Navigate to your GitHub repository.
2. Click the **Pull requests** tab.
3. Click the **New pull request** button.
4. Change the **compare** to `features/05-azure-functions-module`.
5. Click the **Create pull request** button.
6. Click the **Create pull request** button.
7. Once all of the checks have passed, click the **Merge pull request** button.
8. Click the **Confirm merge** button.
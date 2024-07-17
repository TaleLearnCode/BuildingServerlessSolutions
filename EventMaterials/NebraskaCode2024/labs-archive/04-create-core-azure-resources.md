[Design and Develop a Serverless Event-Driven Microservice-Based Solution](https://github.com/TaleLearnCode/EDAMicroserviceWorkshop) \ [Nebraska.Code 2024](README.md)  \ [Labs](README.md) \

# Lab 4: Create Core Azure Resources

## Objective

Part of the mantra of developing microservices is that each microservice shall be self-contained and run on its own set of services. That said, it is not unusual for some common infrastructure resources to be shared amongst different microservices.

For the Cool Revive Remanufacturing system, several Azure services will be shared: the API Management instance, the Service Bus namespace, and the Cosmos DB account.

In this lab, you will build the Terraform project to create these Azure resources.

## Prerequisites

- Completion of  [Lab 4](03-create-service-principal.md) 
- Terraform is installed on your local machine.
- Azure CLI installed and authenticated on your local machine

## Steps

### Step 1: Create the main configuration

1. (If not already) open Visual Studio Code.
2. (If not already) open the repository folder.
3. In the `infra` folder, create the `main.tf` file.

> A common practice in Terraform is to use the `main.tf` file as either the main or only Terraform configuration file in a project. Below, we are going to add the providers, variables, modules, and referenced resources to the `main` file. In most projects, you might consider separating these sections into separate files to make finding what you are looking for easier.

### Step 2: Add provider configuration to main.tf

1. Add the following configuration to the `main.tf` file.

```hcl
# #############################################################################
# Provider Configuration
# #############################################################################

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
  backend "azurerm" {
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}
```

The `providers.tf` file defines the Terraform providers we will use to create resources for the system. Providers are logical abstractions of an upstream API. They are responsible for understanding API interactions and exposing resources.

For this project, we are doing the following in this `providers.tf` file:

- Configuring the overall Terraform project indicates that.
  - We are requiring the latest 3.0 AzureRM provider from the HashiCorp register.
  - We are storing the state of the Terraform project using the AzureRM provider.
- Configuring the AzureRM provider with the following options:
  - Ensuring that any associated Azure resource groups are not deleted if they are not empty.

### Step 3: Add Standard variables to main.tf

1. Add the following variables to the `main.tf` file:

```hcl
# #############################################################################
# Common Variables
# #############################################################################

variable "azure_region" {
	type        = string
  default     = "eastus2"
	description = "Location of the resource group."
}

variable "azure_environment" {
	type        = string
  default     = "dev"
	description = "The environment component of an Azure resource name."
}

variable "resource_name_suffix" {
  type        = string
  default     = "random"
  description = "The suffix to append to the resource names."
}

variable "resource_group_name" {
  type        = string
  default     = "rg-CoolRevive-dev-cus"
  description = "The name of the resource group."
}

variable "company_name" {
  type        = string
  default     = "CoolRevive"
  description = "The name of the company."
}

variable "system_name" {
  type        = string
  default     = "Remanufacturing"
  description = "The name of the system."
}
```

2. Update the default values for the following variables as needed based on the outputs from the previous lab:
   - azure_region
   - azure_environment
   - resource_name_suffix
   - resource_group_name

> Variables can be added anywhere, but a good practice is to put commonly used variables into a centralized location of your Terraform project.

### Step 4: Add tags to main.tf

Add the following configuration to the `main.tf` file:

```hcl
# #############################################################################
#                             Tags
# #############################################################################

variable "tag_product" {
  type        = string
  default     = "Remanufacturing"
  description = "The product or service that the resources are being created for."
}

variable "tag_cost_center" {
  type        = string
  default     = "Remanufacturing"
  description = "Accounting cost center associated with the resource."
}

variable "tag_criticality" {
  type        = string
  default     = "Medium"
  description = "The business impact of the resource or supported workload. Valid values are Low, Medium, High, Business Unit Critical, Mission Critical."
}

variable "tag_disaster_recovery" {
  type        = string
  default     = "Dev"
  description = "Business criticality of the application, workload, or service. Valid values are Mission Critical, Critical, Essential, Dev."
}

locals {
  tags = {
    Product     = var.tag_product
    Criticality = var.tag_criticality
    CostCenter  = "${var.tag_cost_center}-${var.azure_environment}"
    DR          = var.tag_disaster_recovery
    Env         = var.azure_environment
  }
}
```

Azure resources can be tagged using custom key/value pairs. These tags can be used for whatever you need them for. Typical uses are billing, criticality, and disaster recovery identification, which we will use for this project.

### Step 5: Add referenced resources to main.tf

Add the following configuration to the `main.tf` file:

```hcl
# #############################################################################
# Referenced Resoruces
# #############################################################################

data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}
```

You can use the `data` configuration element when you need to reference resources created outside of the project (however they are produced). In the configuration above, we are getting a reference to the current user and the Remanufacturing resource group we created in [Lab 2](02-initiaize-terraform-remote-state.md).

### Step 6: Add modules to main.tf

Add the following module configurations to the `main.tf` file:

```hcl
# #############################################################################
# Modules
# #############################################################################

module "azure_regions" {
  source       = "git::https://github.com/TaleLearnCode/terraform-azure-regions.git"
  azure_region = var.azure_region
}

module "resource_group" {
  source        = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "resource-group"
}

module "api_management" {
  source        = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "api-management-service-instance"
}

module "service_bus_namespace" {
  source        = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "service-bus-namespace"
}

module "cosmos_account" {
  source        = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "azure-cosmos-db-for-nosql-account"
}

module "log_analytics_workspace" {
  source = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
}

module "application_insights" {
  source = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "application-insights"
}
```

A Terraform module is a "collection of standard configuration files in a dedicated directory." Put another way, Terraform modules allow you to have reusable configurations that can be added to a Terraform configuration project. In this Terraform project, we are using two different modules:

- **terraform-azure-regions**: This module provides Azure region information for a specified Azure region.
- **azure-resource-types**: This module helps to keep the consistent naming of Azure resources. The goal of this module is to provide the resource type abbreviation to be used within the name of an Azure resource.

### Step 7: Create the core configuration

In the `infra` folder, add a file named `core.tf`.

> Terraform allows you to put the different configuration elements anywhere with the Terraform project folder you desire as long as it is in a **tf** file. A good practice for a larger project (like this will become) is to create separate **tf** files for each resource/resource type. But to make the labs a little easier, we are grouping resources by area/microservice.

### Step 8: Add the Log Analytics Workspace and Application Insights configuration to core.tf

Add the following configuration to `core.tf`:

```hcl
# #############################################################################
# Log Analytics Workspace
# #############################################################################

resource "azurerm_log_analytics_workspace" "log_analytics" {
  name                = lower("${module.log_analytics_workspace.name.abbreviation}-CoolRevive${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}")
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

# #############################################################################
# Application Insights
# #############################################################################

resource "azurerm_application_insights" "app_insights" {
  name                = lower("${module.application_insights.name.abbreviation}-CoolRevive${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}")
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  workspace_id        = azurerm_log_analytics_workspace.log_analytics.id
  application_type    = "web"
  tags                = local.tags
}
```

### Step 9: Add the Cosmos account configuration to core.tf

Add the following configuration to the `core.tf`:

```hcl
# #############################################################################
# API Management
# #############################################################################

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------

variable "apim_publisher_name" {
  type        = string
  default     = "Nebraska.Code"
  description = "The name of the publisher of the API Management instance."
}

variable "apim_publisher_email" {
  type        = string
  default     = "chad.green@chadgreen.com"
  description = "The email address of the publisher of the API Management instance."
}

variable "apim_sku_name" {
  type        = string
  default     = "Developer_1"
  description = "The SKU of the API Management instance."
}

# -----------------------------------------------------------------------------
# API Management Service Instance
# -----------------------------------------------------------------------------

resource "azurerm_api_management" "apim" {
  name                = lower("${module.api_management.name.abbreviation}-${var.company_name}-${var.azure_environment}-${module.azure_regions.region.region_short}")
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  publisher_name      = var.apim_publisher_name
  publisher_email     = var.apim_publisher_email
  sku_name            = var.apim_sku_name
}
```

### Step 10: Add the API Management service instance configuration to core.tf

1. Add the following configuration to the `core.tf` file:

```hcl
# #############################################################################
# API Management
# #############################################################################

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------

variable "apim_publisher_name" {
  type        = string
  default     = "Nebraska.Code"
  description = "The name of the publisher of the API Management instance."
}

variable "apim_publisher_email" {
  type        = string
  default     = "chad.green@chadgreen.com"
  description = "The email address of the publisher of the API Management instance."
}

variable "apim_sku_name" {
  type        = string
  default     = "Developer_1"
  description = "The SKU of the API Management instance."
}

# -----------------------------------------------------------------------------
# API Management Service Instance
# -----------------------------------------------------------------------------

resource "azurerm_api_management" "apim" {
  name                = lower("${module.api_management.name.abbreviation}-${var.company_name}-${var.azure_environment}-${module.azure_regions.region.region_short}")
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  publisher_name      = var.apim_publisher_name
  publisher_email     = var.apim_publisher_email
  sku_name            = var.apim_sku_name
}
```

2. Update the following variable values to appropriate values:

   - **apim_publisher_name**: The name of the organization publishing the API Management instance.
   - **apim_publisher_email**: The name of the email contact for the API Management instance.

   > [!NOTE]
   >
   > Azure API Management can be set up to be publicly accessible so that an organization can make its APIs available outside of its company. Because of this, API Management requires the definition of a publisher name and email, which is used when the instance is public.

### Step 11: Add the Service Bus Namespace configuration to core.tf

Add the following configuration to the `core.tf` file:

```hcl
# #############################################################################
# Service Bus
# #############################################################################

resource "azurerm_servicebus_namespace" "catalog" {
  name                = lower("${module.service_bus.name.abbreviation}-${var.system_name}${resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}")
  location            = data.azurerm_resource_group.messaging.location
  resource_group_name = data.azurerm_resource_group.messaging.name
  sku                 = "Standard"
  tags                = local.tags
}
```

### Step 12: Setup the backend configuration information

1. Copy the `infra\remote-state\dev.tfconfig` file

> The tfconfig file name uses the `azure_environment` variable value, so if you change that value, the file will be named accordingly.

2. Paste the file into the `infra` folder.

3. Open the `infra\dev.tfconfig` file
4. Update the key value to `remanufacturing.tfstate`

Your `infra\dev.tfconfig` file should look similar to this:

```hcl
storage_account_name = "stterraform000devcus"
container_name = "terraform-state"
key = "remanufacturing.tfstate"
sas_token = "The SAS token"
```

### Step 13: Initialize the Terraform project

In the Visual Studio Code Terminal window, execute the following command:

```sh
terraform init --backend-config="dev.tfconfig"
```

> [!IMPORTANT]
>
> Be sure that you are in the correct directory within the Terminal window. We previously ran commands within the `infra\remote-state` directory, and now we need to execute the commands in the `infra` folder.

Hopefully, you will receive the following message: **Terraform has been successfully installed!** However, part of the initialization process is scanning the project for errors, so you might need to correct something and rerun the `terraform init` command.

### Step 14: Validate the Terraform project

1. In the Visual Studio Code Terminal window, execute the following command:

```hcl
terraform validate
```

> The `terraform validate` command runs checks that verify whether a configuration is syntactically valid and internally consistent, regardless of any provided variables or existing state. It is primarily helpful for verifying reusable modules, including the correctness of attribute names and value types.

> It is best practice to execute the `terraform validate` command whenever you make changes to your Terraform project to ensure that you didn't make any apparent mistakes.

2. Correct any validation errors and rerun the `terraform validate` command until the validation is successful.

### Step 15: Plan the Terraform project

1. In the Visual Studio Code Terminal window, execute the following command:

```hcl
terraform plan
```

> The `terraform plan` command creates an execution plan, letting you preview the changes Terraform will make to your infrastructure.

2. Inspect the Terraform plan to verify it will make the changes you expect.

> The plan results should look like this:
>
> **Plan:** 3 to add, 0 to change, 0 to destroy

### Step 16: Commit and push the Terraform project to your central Git repository

1. Click on the `Source Control` tab within Visual Studio code.
2. Add an appropriate commit message:

```
Adding the primary Terraform configuration project.
```

3. Click the **Commit** button (this will perform a `git commit` command).
4. Click the **Sync Changes** button (this will perform a `git push` command).

> [!NOTE]
>
> In the next lab, instead of applying the Terraform configuration locally, we will set up the pipelines to handle that automatically.

## Conclusion

In this lab, you initialize the primary Terraform configuration project, which will manage the resources for the Cool Revive Remanufacturing system.

## Next Steps

In the next lab, you will build the software development platform pipeline to automatically apply the Terraform configuration changes when pushed to the development branch.
[Design and Develop a Serverless Event-Driven Microservice-Based Solution](https://github.com/TaleLearnCode/EDAMicroserviceWorkshop) \ [Nebraska.Code 2024](README.md)  \ [Labs](README.md) \

# Lab 7: Create the Production Schedule App

## Objective

At Cool Revive Technologies, schedule management defines the schedule for each remanufacturing pod's daily unit build based on orders and stocking needs. This is done in the **Production Schedule** application outside the remanufacturing domain. We will create a simple data store for this workshop to represent the **Production Schedule** application since that is all we need to interact with.

In our scenario, the **Production Schedule** application is a legacy application and is not scheduled to be moved to the cloud until later. As such, Cool Revive Technologies has decided not to update the application to meet the system's needs until they move the application to the cloud. As such, we will create a **Production Schedule Facade** service that will provide the needed functionality to the **Remanufacturing** system in a way that will be expected when the **Production Schedule** application is migrated to reduce the need to re-engineer **Remanufacturing** later on.

The necessary endpoints of the **Production Schedule Facade** will be put into the **API Management** instance to provide a single endpoint URL. This helps promote the *strangler* pattern, as when the **Production Schedule** application is migrated, and the **Production Schedule Facade** is no longer needed, the API Management instance can be updated, and the applications using that endpoint in API Management will not need to make changes.

## Prerequisites

- Completion of [Lab 6](06-app-config-secret-module.md).
- Terraform is installed on your local machine.
- Azure CLI installed and authenticated on your local machine

## Steps

### Step 1: Create the feature branch for this lab

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
git branch features/07-production-schedule
```

5. Checkout the feature branch for the lab:

```sh
git checkout features/07-production-schedule
```

### Step 2: Simulate the Production Schedule legacy application

For this workshop, we will simulate the Production Schedule legacy application by creating a simple data store.

1. In Visual Studio Code, open the `infra\modules.tf` file and add the following:

```
module "storage_account" {
  source        = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "storage-account"
}
```

2. In Visual Studio Code, open the `infra\global.tf` file and add the following to the file:

```
# -----------------------------------------------------------------------------
# Storage Account
# -----------------------------------------------------------------------------

resource "azurerm_storage_account" "global" {
  name                     = "${module.storage_account.name.abbreviation}crt${var.resource_name_suffix}${var.azure_environment}${module.azure_regions.region.region_short}"
  resource_group_name      = azurerm_resource_group.global.name
  location                 = azurerm_resource_group.global.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.global_tags
}

module "global_storage_account_connection_string" {
  source                 = "./modules/app-config-secret"
  app_config_label       = var.azure_environment
  app_config_key         = "Global:StorageAccount:ConnectionString"
  configuration_store_id = azurerm_app_configuration.remanufacturing.id
  key_vault_id           = azurerm_key_vault.remanufacturing.id
  secret_name            = "Global-StorageAccount-ConnectionString"
  secret_value            = azurerm_storage_account.global.primary_connection_string
}
```

3. Create the `infra\production-schedule.tf` file and initialize the file with the following:

```
# #############################################################################
# Production Schedule
# #############################################################################
```

4. Add the following to the `production-schedule.tf` file to create the table we will store simulated schedule data:

```
# ------------------------------------------------------------------------------
# Production Schedule "Legacy Application"
# ------------------------------------------------------------------------------

resource "azurerm_storage_table" "production_schedule" {
  name                 = "ProductionSchedule"
  storage_account_name = azurerm_storage_account.global.name
}

resource "azurerm_app_configuration_key" "production_schedule_table_name" {
  configuration_store_id = azurerm_app_configuration.remanufacturing.id
  key                    = "ProductionSchedule:Storage:TableName"
  label                  = var.azure_environment
  value                  = azurerm_storage_table.production_schedule.name
  lifecycle {
    ignore_changes = [configuration_store_id]
  }
}
```

6. Add the random provider to the `infra\providers.tf` file. Your file should look like this after adding the random provider:

```HCL
# #############################################################################
# Provider Configuration
# #############################################################################

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    random = {
      source = "hashicorp/random"
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

7. Add the following to the `production-schedule.tf` file to simulate the production schedule data:

```
locals {
  current_date = formatdate("YYYY-MM-DD", timestamp())
  core_ids = {
    0 = "ABC123"
    1 = "DEF456"
    2 = "GHI789"
    3 = "JKL987"
    4 = "MNO654"
    5 = "PQR321"
    6 = "STU159"
    7 = "VWX357"
    8 = "ZYA753"
    9 = "DCB951"
  }
}

resource "random_string" "finished_product_id" {
  length  = 10
  special = false
  upper   = true
}

resource "azurerm_storage_table_entity" "production_schedule_pod123" {
  count            = 10
  storage_table_id = azurerm_storage_table.production_schedule.id
  partition_key    = "pod123_${local.current_date}"
  row_key          = count.index + 1
  entity = {
    "PodId"    = "pod123",
    "Date"     = local.current_date,
    "Sequence" = count.index,
    "Model"    = "Model 3",
    "CoreId"   = local.core_ids[count.index],
    "FinishedProductId" = random_string.finished_product_id.result,
    "Status"   = "Scheduled",
  }
}
```

### Step 3: Create the Key Vault store

We will create an Azure Key Vault store to store the secrets that our applications need securely.

1. Add the following module to the `infra\modules.tf` file:

```HCL
module "key_vault" {
  source = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "key-vault"
}
```

1. Create the `infra\remanufacturing.tf` file and initialize the file with the following:

```HCL
# #############################################################################
# Remanufacturing
# #############################################################################

# -----------------------------------------------------------------------------
#                             Tags
# -----------------------------------------------------------------------------

variable "remanufacturing_tag_product" {
  type        = string
  default     = "Remanufacturing"
  description = "The product or service that the resources are being created for."
}

variable "remanufacturing_tag_cost_center" {
  type        = string
  default     = "Remanufacturing"
  description = "Accounting cost center associated with the resource."
}

variable "remanufacturing_tag_criticality" {
  type        = string
  default     = "Medium"
  description = "The business impact of the resource or supported workload. Valid values are Low, Medium, High, Business Unit Critical, Mission Critical."
}

variable "remanufacturing_tag_disaster_recovery" {
  type        = string
  default     = "Dev"
  description = "Business criticality of the application, workload, or service. Valid values are Mission Critical, Critical, Essential, Dev."
}

locals {
  remanufacturing_tags = {
    Product     = var.remanufacturing_tag_product
    Criticality = var.remanufacturing_tag_criticality
    CostCenter  = "${var.global_tag_cost_center}-${var.azure_environment}"
    DR          = var.remanufacturing_tag_disaster_recovery
    Env         = var.azure_environment
  }
}

# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------

resource "azurerm_resource_group" "remanufacturing" {
  name     = "${module.resource_group.name.abbreviation}-CoolRevive_Remanufacturing-${var.azure_environment}-${module.azure_regions.region.region_short}"
  location = module.azure_regions.region.region_cli
  tags     = local.global_tags
}
```

This will initialize the tags for the Remanufacturing group of resources and create the Resource Group where the Azure resources will be grouped.

2. Add the following to the `remanufacturing.tf` to add the Key Vault configuration:

```HCL
# -----------------------------------------------------------------------------
# Key Vault
# -----------------------------------------------------------------------------

resource "azurerm_key_vault" "remanufacturing" {
  name                        = lower("${module.key_vault.name.abbreviation}-Reman${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}")
  location                    = azurerm_resource_group.remanufacturing.location
  resource_group_name         = azurerm_resource_group.remanufacturing.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = true
  sku_name                    = "standard"
  enable_rbac_authorization  = true
  tags                        = local.remanufacturing_tags
}

resource "azurerm_role_assignment" "key_vault_administrator" {
  scope                = azurerm_key_vault.remanufacturing.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}
```

### Step 4: Create the App Configuration store

The Azure App Config store is an excellent service that provides a convenient way to store application configuration values.

1. Add the following module to the `infra\modules.tf` file:

```HCL
module "app_config" {
  source = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "app-configuration-store"
}
```

2. Add the following to the `remanufacturing.tf` to add the App Config configuration:

```HCL
# -----------------------------------------------------------------------------
# App Configuration
# -----------------------------------------------------------------------------

resource "azurerm_app_configuration" "remanufacturing" {
  name                       = lower("${module.app_config.name.abbreviation}-Remanufacturing${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}")
  resource_group_name        = azurerm_resource_group.remanufacturing.name
  location                   = azurerm_resource_group.remanufacturing.location
  sku                        = "standard"
  local_auth_enabled         = true
  public_network_access      = "Enabled"
  purge_protection_enabled   = false
  soft_delete_retention_days = 1
  tags                       = local.remanufacturing_tags
}

# Role Assignment: 'App Configuration Data Owner' to current Terraform user
resource "azurerm_role_assignment" "app_config_data_owner" {
  scope                = azurerm_app_configuration.remanufacturing.id
  role_definition_name = "App Configuration Data Owner"
  principal_id         = data.azurerm_client_config.current.object_id
}
```

3. Validate that are no errors in the configuration:

```
terraform init --backend-config="dev.tfconfig"
terraform validate
terraform plan --var-file=dev.tfvars
```

With each command, validate that the output was successful; correct any issues.

### Step 5: Create the App Insights service

Azure **Application Insights** is a feature of **Azure Monitor** that provides Application Performance Management (APM) for live web applications. It excels at telemetry collection, which is important for tracking an application's performance, health, and usage.

1. Add the following module to the `infra\modules.tf` file:

```HCL
module "log_analytics_workspace" {
  source = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "log-analytics-workspace"
}

module "application_insights" {
  source = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "application-insights"
}
```

2. Add the following to the `remanufacturing.tf` to add the App Config configuration:

```HCL
# -----------------------------------------------------------------------------
# Log Analytics Workspace
# -----------------------------------------------------------------------------

resource "azurerm_log_analytics_workspace" "remanufacturing" {
  name                = lower("${module.log_analytics_workspace.name.abbreviation}-Remanufacturing${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}")
  location            = azurerm_resource_group.remanufacturing.location
  resource_group_name = azurerm_resource_group.remanufacturing.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.remanufacturing_tags
}

# -----------------------------------------------------------------------------
# Application Insights
# -----------------------------------------------------------------------------

resource "azurerm_application_insights" "remanufacturing" {
  name                = lower("${module.application_insights.name.abbreviation}-Remanufacturing${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}")
  location            = azurerm_resource_group.remanufacturing.location
  resource_group_name = azurerm_resource_group.remanufacturing.name
  workspace_id        = azurerm_log_analytics_workspace.remanufacturing.id
  application_type    = "web"
  tags                = local.remanufacturing_tags
}
```

3. Validate that are no errors in the configuration:

```
terraform init --backend-config="dev.tfconfig"
terraform validate
terraform plan --var-file=dev.tfvars
```

With each command, validate that the output was successful; correct any issues.

### Step 6: Create the Production Schedule facade application

1. Add the following to the `production-schedule.tf` file to create the Azure Function app infrastructure for the **Production Schedule Facade** application:

```HCL
# ------------------------------------------------------------------------------
# Production Schedule Facade
# ------------------------------------------------------------------------------

module "production_schedule_facade" {
  source = "./modules/function-consumption"
  app_configuration_id           = azurerm_app_configuration.remanufacturing.id
  app_insights_connection_string = azurerm_application_insights.remanufacturing.connection_string
  azure_environment              = var.azure_environment
  azure_region                   = var.azure_region
  function_app_name              = "ProductionScheduleFacade"
  key_vault_id                   = azurerm_key_vault.remanufacturing.id
  resource_group_name            = azurerm_resource_group.remanufacturing.name
  resource_name_suffix           = var.resource_name_suffix
  storage_account_name           = "psf"
  tags                           = local.remanufacturing_tags
  #app_settings = {
  #  "TableConnectionString"       = "@Microsoft.AppConfiguration(Endpoint=${azurerm_app_configuration.remanufacturing.endpoint}; Key=${module.global_storage_account_connection_string.key}; Label=${module.global_storage_account_connection_string.label})",
  #  "ProductionScheduleTableName" = "@Microsoft.AppConfiguration(Endpoint=${azurerm_app_configuration.remanufacturing.endpoint}; Key=${azurerm_app_configuration_key.production_schedule_table_name.key}; Label=${azurerm_app_configuration_key.production_schedule_table_name.label})",
  #}
  app_settings = {
    "TableConnectionString"       = azurerm_storage_account.global.primary_connection_string
    "ProductionScheduleTableName" = azurerm_storage_table.production_schedule.name
  }
  depends_on = [ azurerm_resource_group.remanufacturing ]
}
```

> [!NOTE]
>
> Here is a case where we put a module somewhere other than the `modules.tf` file. This makes organizational sense, along with parts of its module.

2. Validate that are no errors in the configuration:

```
terraform validate
terraform plan --var-file=dev.tfvars
```

With each command, validate that the output was successful; correct any issues.

### Step 7: Commit and push the Terraform project to your central Git repository

1. Click on the `Source Control` tab within Visual Studio code.
2. Add an appropriate commit message:

```
Adding infrastructure for Production Schedule.
```

3. Click the **Commit** button (this will perform a `git commit` command).
4. Click the **Publish Branch** button (this will perform a `git push` command).

### Step 8: Create a pull request and merge it into develop

#### Using GitHub

1. Navigate to your GitHub repository.
2. Click the **Pull requests** tab.
3. Click the **New pull request** button.
4. Change the **compare** to `features/07-production-schedule`.
5. Click the **Create pull request** button.
6. Click the **Create pull request** button.
7. Once all of the checks have passed, click the **Merge pull request** button.
8. Click the **Confirm merge** button.
9. Open the **Actions** tab and validate that the `Terraform (CD)` pipeline is running.

Validate that the **Terraform (cd)** pipeline is executed successfully.

### Step 9: Initialize the Remanufacturing solution

1. Launch Visual Studio.

> You can continue to use Visual Studio code for the following steps, but the instructions are written for Visual Studio.

2. Click the "**Create a new project**" button from the Visual Studio **Start Window**.
3. Search for **Blank Solution** and click the **Next** button.
4. Enter `Remanufacturing` in the "**Solution name**" field and search for the `src` folder within your *Cool Revive Remanufacturing* repository folder. Click the **Create** button.

### Step 10: Create the Responses class library

The Responses class library provides a consistent method for Remanufacturing logic to send responses to consumers.

1. Rick-click the `Remanufacturing` solution and select **Add** > **New Solution Folder**. Name the new folder `Core`.
2. Right-click the `Core` solution folder and select **Add** > **New Project**.
3. Search for and select **Class Library**, and then click the **Next** button.
4. Enter `Responses` as the **Project name**.
5. Append `Core` to the Location path. For example, `C:\Rerpos\cool-revive-remanufacturing\src\Core`.

>  Putting the module's projects into a specific folder will help organize the source structure.

6. Click the **Next** button.
7. Select `.NET 8.0 (Long Term Support)` for the **Framework** and click the **Create** button.
8. Delete the `Class1.cs` file.
9. Double-click the `Reponses` project to open the csproj file.
10. Add `<RootNamespace>Remanufacturing</RootNamespace>` to the `PropertyGroup`. Your csproj file should resemble:

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <RootNamespace>Remanufacturing</RootNamespace>
  </PropertyGroup>

</Project>
```

11. Add a folder named `Reponses` to the `Repsonses` project.
12. Add an interface to the `Responses` folder named `IResponse.cs` and replace the default content with:

```c#
using System.Net;

namespace Remanufacturing.Responses;

/// <summary>
/// Represents a response object based off of the RFC 7807 specification.
/// </summary>
public interface IResponse
{

	/// <summary>
	/// A URI reference that identifies the response type. This specification encourages that, when dereferenced, it provide human-readable documentation for the response type.
	/// </summary>
	string Type { get; set; }

	/// <summary>
	/// A short, human-readable summary of the response. It SHOULD NOT change from occurrence to occurrence of the response type, except for purposes of localization.
	/// </summary>
	string Title { get; set; }

	/// <summary>
	/// The HTTP status code for the response.
	/// </summary>
	HttpStatusCode Status { get; set; }

	/// <summary>
	/// A human-readable explanation specific to this occurrence of the response.
	/// </summary>
	string? Detail { get; set; }

	/// <summary>
	/// A URI reference that identifies the specific occurrence of the response. It may or may not yield further information if dereferenced.
	/// </summary>
	string? Instance { get; set; }

	/// <summary>
	/// Additional details about the response that may be helpful when receiving the response.
	/// </summary>
	Dictionary<string, object>? Extensions { get; set; }

}
```

13. Add a class to the `Responses` folder named `ProblemDetails.cs` and replace the default text with:

```C#
using System.Net;

namespace Remanufacturing.Responses;

/// <summary>
/// Represents the details of a HTTP problem or error based off of RFC 7807.
/// </summary>
public class ProblemDetails : IResponse
{

	/// <summary>
	/// A URI reference that identifies the problem type. This specification encourages that, when dereferenced, it provide human-readable documentation for the problem type.
	/// </summary>
	public string Type { get; set; } = null!;

	/// <summary>
	/// A short, human-readable summary of the problem type. It SHOULD NOT change from occurrence to occurrence of the problem, except for purposes of localization.
	/// </summary>
	public string Title { get; set; } = null!;

	/// <summary>
	/// The HTTP status code generated by the origin server for this occurrence of the problem.
	/// </summary>
	public HttpStatusCode Status { get; set; }

	/// <summary>
	/// A human-readable explanation specific to this occurrence of the problem.
	/// </summary>
	public string? Detail { get; set; }

	/// <summary>
	/// A URI reference that identifies the specific occurrence of the problem. It may or may not yield further information if dereferenced.
	/// </summary>
	public string? Instance { get; set; }

	/// <summary>
	/// Additional details about the problem that may be helpful when debugging the problem.
	/// </summary>
	public Dictionary<string, object>? Extensions { get; set; } = new Dictionary<string, object> { { "traceId", Guid.NewGuid() } };

	public ProblemDetails() { }

	public ProblemDetails(ArgumentException exception, string? instance = null)
	{
		Type = "https://example.net/validation-error"; // HACK: In a real-world scenario, you would want to provide a more-specific URI reference that identifies the response type.
		Title = "One or more validation errors occurred.";
		Status = HttpStatusCode.BadRequest;
		Detail = exception.Message;
		Instance = instance;
		if (exception.ParamName != null)
			Extensions = new Dictionary<string, object>
			{
				{ "traceId", Guid.NewGuid() },
				{ "errors", new Dictionary<string, string[]> { { exception.ParamName, new[] { exception.Message } } } }
		};
	}

}
```

14. Add a class to the `Responses` folder named `StandardResponse.cs` and replace the default text with:

```C#
using System.Net;

namespace Remanufacturing.Responses;

/// <summary>
/// Represents the standard response for an HTTP endpoint derived from RFC 7807.
/// </summary>
public class StandardResponse : IResponse
{

	/// <summary>
	/// A URI reference that identifies the response type. This specification encourages that, when dereferenced, it provide human-readable documentation for the response type.
	/// </summary>
	public string Type { get; set; } = null!;

	/// <summary>
	/// A short, human-readable summary of the response. It SHOULD NOT change from occurrence to occurrence of the response type, except for purposes of localization.
	/// </summary>
	public string Title { get; set; } = null!;

	/// <summary>
	/// The HTTP status code for the response.
	/// </summary>
	public HttpStatusCode Status { get; set; } = HttpStatusCode.OK;

	/// <summary>
	/// A human-readable explanation specific to this occurrence of the response.
	/// </summary>
	public string? Detail { get; set; }

	/// <summary>
	/// A URI reference that identifies the specific occurrence of the response. It may or may not yield further information if dereferenced.
	/// </summary>
	public string? Instance { get; set; }

	/// <summary>
	/// Additional details about the response that may be helpful when receiving the response.
	/// </summary>
	public Dictionary<string, object>? Extensions { get; set; }

}
```

### Step 11: Create the Production Schedule Facade services class library

A good practice when developing Azure Functions is to put the logic for the Azure Functions in a separate class library and then reference that class library from the Azure Functions project. This allows for better unit testing (although we will not write unit tests during this workshop).

1. Right-click the `Remanufacturing` solution and select **Add** > **New Solution Folder**. Name the new folder `Production Schedule`.
2. Right-click the `Production Schedule` solution folder and select **Add** > **New Project**.
3. Search for and select **Class Library,** and then click the **Next** button.
4. Enter `ProductionScheduleFacade.Services` as the "**Project name**"
5. Append `ProductionSchedule` to the Location path. For example, `C:\Repos\cool-revive-remanufacturing\src\ProductionSchedule`.
6. Click the **Next** button.
7. Select `.NET 8.0 (Long Term Support)` for the **Framework** and click the **Create** button.
8. Delete the `Class1.cs` file. 
9. Double-click the `ProductionScheduleFacade.Services` project to open the csproj file.
10.  Add `<RootNamespace>Remanufacutring.ProductionScheduleFacade</RootNamespace>` to the `PropertyGroup`. Your csproj file should resemble:

```xml	
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <RootNamespace>Remanufacturing.ProductionScheduleFacade</RootNamespace>
  </PropertyGroup>

</Project>
```

11. From the **Package Manager Console** window in Visual Studio, ensure the default project is `Production Schedule\ProductionScheduleFacade.Services`, and install the `Azure.Data.Tables` package:

```bash
NuGet\Install-Package Azure.Data.Tables -Version 12.8.3
```

12. Also, install the `Azure.Identity` package:

```bash
NuGet\Install-Package Azure.Identity -Version 1.12.0
```

13. Right-click `ProductrionScheduleFacade.Serices` and select **Add** > **Project Reference**.
14. Select `Responses` and click the **OK** button.
15. Add a folder named `TableEntities` to the project.
16. Add a class named `ProductionScheduleTableEntity.cs` to the `TableEntities` folder and replace the contents with:

```c#
#nullable disable

using Azure;
using Azure.Data.Tables;

namespace Remanufacturing.ProductionScheduleFacade.TableEntities;

public class ProductionScheduleTableEntity : ITableEntity
{

	public string PodId { get; set; } = null!;
	public string Date { get; set; }
	public string Sequence { get; set; }
	public string Model { get; set; } = null!;
	public string CoreId { get; set; } = null!;
	public string FinishedProductId { get; set; } = null!;
	public string Status { get; set; } = null!;


	public string PartitionKey { get; set; } = null!;
	public string RowKey { get; set; } = null!;
	public DateTimeOffset? Timestamp { get; set; }
	public ETag ETag { get; set; }

}
```

17. Add a folder named `Services` to the project.
18. Add a class named `ProductionScheduleFacadeServices.cs` to the `Services` folder and replace the contents with:

```c#
using Azure.Data.Tables;
using Remanufacturing.ProductionScheduleFacade.TableEntities;
using Remanufacturing.Responses;
using System.Globalization;
using System.Net;

namespace Remanufacturing.ProductionScheduleFacade.Services;

public class ProductionScheduleFacadeServices(TableClient tableClient)
{

	private readonly TableClient _tableClient = tableClient;

	public async Task<IResponse> GetNextCoreAsync(string podId, string date, string instance)
	{
		try
		{

			ArgumentException.ThrowIfNullOrWhiteSpace(podId, nameof(podId));
			if (!DateTime.TryParseExact(date, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out _))
				throw new ArgumentException("The date is not in the correct format.", nameof(date));

			List<ProductionScheduleTableEntity> productionSchedule = [.. _tableClient.Query<ProductionScheduleTableEntity>(x => x.PartitionKey == $"{podId}_{date}")];
			productionSchedule.Sort((x, y) => x.Sequence.CompareTo(y.Sequence));

			ProductionScheduleTableEntity? nextCore = productionSchedule.Where(x => x.Status == "Scheduled").FirstOrDefault();
			if (nextCore is not null)
			{

				nextCore.Status = "In Production";
				nextCore.ETag = new Azure.ETag("*");
				await _tableClient.UpdateEntityAsync(nextCore, nextCore.ETag);

				return new StandardResponse()
				{
					Type = "https://httpstatuses.com/200", // HACK: In a real-world scenario, you would want to provide a more-specific URI reference that identifies the response type.
					Title = "Next core on the production schedule retrieved successfully.",
					Status = HttpStatusCode.OK,
					Detail = "Next core on the production schedule retrieved successfully.",
					Instance = instance,
					Extensions = new Dictionary<string, object>()
					{
						{ "PodId", nextCore.PodId },
						{ "Date", nextCore.Date },
						{ "Sequence", nextCore.Sequence },
						{ "Model", nextCore.Model },
						{ "CoreId", nextCore.CoreId },
						{ "FinishedProductId", nextCore.FinishedProductId }
					}
				};
			}
			else
			{
				return new ProblemDetails()
				{
					Type = "https://httpstatuses.com/204", // HACK: In a real-world scenario, you would want to provide a more-specific URI reference that identifies the response type.
					Title = "No (more) cores are scheduled for production on the specified date.",
					Status = HttpStatusCode.NoContent,
					Detail = "No (more) cores are scheduled for production on the specified date.",
					Instance = instance
				};
			}
		}
		catch (ArgumentException ex)
		{
			return new ProblemDetails(ex, instance);
		}
		catch (Exception ex)
		{
			return new ProblemDetails()
			{
				Type = "https://httpstatuses.com/500", // HACK: In a real-world scenario, you would want to provide a more-specific URI reference that identifies the response type.
				Title = "An error occurred while retrieving the next core on the production schedule.",
				Status = HttpStatusCode.InternalServerError,
				Detail = ex.Message, // HACK: In a real-world scenario, you would not want to expose the exception message to the client.
				Instance = instance
			};
		}
	}

}
```

In this example, the facade service directly uses the Production Schedule data store to retrieve the needed data. It will retrieve the next `Scheduled` record for the requesting pod and then set that record's status to `In Production`.

### Step 12: Create the Production Schedule Facade Azure Function app

1. Right-click the `Production Schedule` solution folder and select **Add** > **New Project**.
3. Search for and select **Azure Function,** and then click the **Next** button.
4. Enter `ProductionScheduleFacade.Functions` as the "**Project name**"
5. Append `ProductionSchedule` to the Location path. For example, `C:\Repos\cool-revive-remanufacturing\src\ProductionSchedule`.
6. Click the **Next** button.
7. Select `.NET 8.0 (Long Term Support)` for the **Functions worker**.
8. Select the **Http trigger** in the **Function** field.
9.  Click the **Create** button.
10. Delete the `Function1.cs` file.
11. Double-click the `ProductionScheduleFacade.Functions` project to open the csproj file.
12.  Add `<RootNamespace>Remanufacturing.ProductionScheduleFacade</RootNamespace>` to the `PropertyGroup`.

13. Right click the `Dependencies` option in the `ProductionScheduleFacade.Functions` project and select **Add Project Reference**.
14. Select the `ProductionScheduleFacade.Services` project and click the **OK** button.
15. Open the `Program.cs` file and replace the default code with:

```c#
using Azure.Data.Tables;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Remanufacturing.ProductionScheduleFacade.Services;

TableServiceClient tableServiceClient = new(Environment.GetEnvironmentVariable("TableConnectionString")!);
TableClient tableClient = tableServiceClient.GetTableClient(Environment.GetEnvironmentVariable("ProductionScheduleTableName")!);


IHost host = new HostBuilder()
	.ConfigureFunctionsWebApplication()
	.ConfigureServices(services =>
	{
		services.AddApplicationInsightsTelemetryWorkerService();
		services.ConfigureFunctionsApplicationInsights();
		services.AddSingleton(new ProductionScheduleFacadeServices(tableClient));
	})
	.Build();

host.Run();
```

The changes to the default code are:

- Adding the logic to initialize a TableServiceClient and TableClient.
- Adding the dependency injection for the **ProductionScheduleFacadeServices**.

16. Add a `Functions` folder to the `ProductionScheduleFacade.Functions` project.
17. Right-click the `Functions` folder and select **New Azure Function...**.
18. Name the Azure Function `GetNextCore.cs`; click the **Add** button.
19. Select **Http trigger** and click the **Add** button.
20. Replace the default code with the following:

```C#
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Remanufacturing.ProductionScheduleFacade.Services;
using Remanufacturing.Responses;
using System.Net;

namespace Remanufacturing.ProductionScheduleFacade.Functions;

public class GetNextCore(ILogger<GetNextCore> logger, ProductionScheduleFacadeServices productionScheduleFacadeServices)
{

	private readonly ILogger<GetNextCore> _logger = logger;
	private readonly ProductionScheduleFacadeServices _productionScheduleFacadeServices = productionScheduleFacadeServices;

	[Function("GetNextCore")]
	public async Task<IActionResult> RunAsync([HttpTrigger(AuthorizationLevel.Function, "get", Route = "{podId}/{date}")] HttpRequest request,
		string podId,
		string date)
	{

		IResponse response;

		try
		{
			_logger.LogInformation("Getting the next core on the production schedule.");
			response = await _productionScheduleFacadeServices.GetNextCoreAsync(podId, date, request.HttpContext.TraceIdentifier);
		}
		catch (Exception ex)
		{
			response = new Remanufacturing.Responses.ProblemDetails()
			{
				Type = "https://httpstatuses.com/500", // HACK: In a real-world scenario, you would want to provide a more-specific URI reference that identifies the response type.
				Title = "An error occurred while retrieving the next core on the production schedule.",
				Status = HttpStatusCode.InternalServerError,
				Detail = ex.Message, // HACK: In a real-world scenario, you would not want to expose the exception message to the client.
				Instance = request.HttpContext.TraceIdentifier
			};
		}

		if (response is StandardResponse standardResponse)
		{
			return new OkObjectResult(standardResponse);
		}
		else
		{
			return new ObjectResult(response)
			{
				StatusCode = (int)HttpStatusCode.OK
			};
		}
	}

}
```

### Step 13: Configure the Function App for running locally

One of the great features of Azure Functions is that they can be run and debugged locally. There are two settings that the function app will need to execute.

1. Navigate to the [Azure Portal](https://portal.azure.com).
2. Search for `stcrt` and click on the appropriate storage account.
3. Click on the **Access keys** tab.
4. Copy one of the Connection strings.
5. In the `ProductionScheduleFacade.Functions` project, open the `local.settings.json` file.
6. Add a `TableConnectionString` key/value pair using the connection string you copied above.
7. Add a `ProductionScheduleTableName` key/value pair with `ProductionSchedule` as the value.

Your `local.settings.json` file should like similar to:

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
    "TableConnectionString": "<<STORAGE_CONNECTION_STRING>>",
    "ProductionScheduleTableName": "ProductionSchedule"
  }
}
```

### Step 14: Test the Production Schedule Facade locally

1. Right-click the `ProductionScheduleFacade.Functions` project and click **Set as Startup Project**.
2. Press **F5** to start the application.
3. Copy the **GetNextCore** url.
4. Open Postman.
5. Enter the URL and change the pod and data, something similar to `http://localhost:7112/api/pod123/2024-07-14`
6. Click the **Send** button.

You should receive a response similar to:

```json
{
    "type": "https://httpstatuses.com/200",
    "title": "Next core on the production schedule retrieved successfully.",
    "status": 200,
    "detail": "Next core on the production schedule retrieved successfully.",
    "instance": "0HN53LI983OD8:00000001",
    "extensions": {
        "PodId": "pod123",
        "Date": "2024-07-14",
        "Sequence": "0",
        "Model": "Model 3",
        "CoreId": "ABC123",
        "FinishedProductId": "xJB4QCaQyw"
    }
}
```

### Step 15: Create a solution for the Production Schedule Facade

We will create a separate solution file for them to use to ease the build process in the upcoming YAML pipelines.

1. In Visual Studio, close the solution.
2. Click the Create a new project button from the Visual Studio Start Window.
3. Search for and click the **Blank Solution** option; click the **Next** button.
4. Enter `ProductionScheduleFacade` in the name and select the `ProductionSchedule` folder with your local repository.
5. Close the solution.
6. Click the **Open a local folder** button from the Visual Studio Start Window.
7. Select your repository folder.
8. Drag the `ProductionScheduleFacade.sln` file from the `..\src\ProductionSchedule\ProductionSchedule` folder to the `...\src\ProductionSchedule` folder.
9. Delete the `...\src\ProductionSchedule\ProductionSchedule` folder.
10. Double-click the `ProductionScheduleFacade.sln` file.
11. Add the `..\src\Core\Responses\Responses.csproj` project to the solution.
12. Add the `..\src\ProductionSchedule\ProductionScheduleFacade.Services\ProductionScheduleFacade.Services.csproj` project to the solution.
13. Add the `..\src\ProductionSchedule\ProductionScheduleFacade.Functions\ProductionScheduleFacade.Functions.csproj` project to the solution.
14. Build the solution and correct any problems.

### Step 16: Update the CI Pipeline

1. Open the `.github\workflows\ci.yml` pipeline.
2. Add `production-schedule-facade: ${{ steps.filter.outputs.production-schedule-facade }}` to the `path-filter` job's `outputs`.
3. Add the following filter to the `path-filter` step:

```yaml
            production-schedule-facade:
              - 'src/ProductionSchedule/**'
```

4. Add the following `production-schedule-facade` job to the pipeline:

```yaml
production-schedule-facade:
    name: 'Production Schedule Facade CI'
    needs: paths-filter
    runs-on: ubuntu-latest
    if: needs.paths-filter.outputs.production-schedule-facade == 'true'
    steps:
    - name: Checkout code
      uses: actions/checkout@v2

    - name: Set up .NET Core
      uses: actions/setup-dotnet@v1
      with:
        dotnet-version: '8.x'

    - name: Restore dependencies
      run: dotnet restore
      working-directory: ./src/ProductionSchedule

    - name: Build project
      run: dotnet build ProductionScheduleFacade.sln --configuration Release
      working-directory: ./src/ProductionSchedule
      
    - name: Publish artifacts
      run: dotnet publish --configuration Release --output ./publish
      working-directory: ./src/ProductionSchedule

    - name: Upload artifacts
      uses: actions/upload-artifact@v2
      with:
        name: csharp-artifacts
        path: ./publish
```

### Step 17: Update the CD Pipeline

1. Open the `.github\workflows\cd.yml` pipeline.
2. Add `production-schedule-facade: ${{ steps.filter.outputs.production-schedule-facade }}` to the `path-filter` job's `outputs`.
3. Add the following filter to the `path-filter` step:

```yaml
            production-schedule-facade:
              - 'src/ProductionSchedule/**'
```

4. Add the following `production-schedule-facade` job to the pipeline:

```yaml
  production-schedule-facade:
    name: 'Production Schedule Facade CI'
    needs: paths-filter
    env:
      AZURE_FUNCTIONAPP_NAME: '<<FUNCTION_APP_NAME>>'
      AZURE_FUNCTIONAPP_PACKAGE_PATH: 'src/ProductionSchedule/ProductionScheduleFacade.Functions'
      DOTNET_VERSION: '8.0.x'
    runs-on: ubuntu-latest
    if: needs.paths-filter.outputs.production-schedule-facade == 'true'
    steps:
      - name: 'Checkout GitHub Action'
        uses: actions/checkout@v3
  
      - name: Setup DotNet ${{ env.DOTNET_VERSION }} Environment
        uses: actions/setup-dotnet@v3
        with:
          dotnet-version: ${{ env.DOTNET_VERSION }}
  
      - name: 'Resolve Project Dependencies Using Dotnet'
        shell: bash
        run: |
          pushd './${{ env.AZURE_FUNCTIONAPP_PACKAGE_PATH }}'
          dotnet build --configuration Release --output ./output
          popd
  
      - name: 'Run Azure Functions Action'
        uses: Azure/functions-action@v1
        id: fa
        with:
          app-name: ${{ env.AZURE_FUNCTIONAPP_NAME }}
          package: '${{ env.AZURE_FUNCTIONAPP_PACKAGE_PATH }}/output'
          publish-profile: ${{ secrets.PRODUCTION_SCHEDULE_FACADE_PUBLISH_PROFILE }}
```

Replace `<<FUNCTION_APP_NAME>>` with the name of the `func-ProductionScheduleFacade` Azure Function App.

### Step 18: Commit and push the Terraform project to your central Git repository

1. Click on the `Source Control` tab within Visual Studio code.
2. Add an appropriate commit message:

```
Adding the Production Schedule Facade Azure Function.
```

3. Click the **Commit** button (this will perform a `git commit` command).
4. Click the **Synch Changes** button.

### Step 19: Create a pull request and merge it into develop

#### Using GitHub

1. Navigate to your GitHub repository.
2. Click the **Pull requests** tab.
3. Click the **New pull request** button.
4. Change the **compare** to `features/07-production-schedule`.
5. Click the **Create pull request** button.
6. Click the **Create pull request** button.
7. Once all of the checks have passed, click the **Merge pull request** button.
8. Click the **Confirm merge** button.
9. Open the **Actions** tab in a separate browser tab and validate that the `Terraform (CD)` pipeline is running.

### Step 20: Setup the Production Schedule API Product

To create the Production Schedule Facade endpoint in Azure API Management, we will first need to create an API Management Product:

1. From the [Azure Portal](https://portal.azure.com), search for `apim-coolrevive` and select the appropriate API Management instance.
2. Go to the **Products** tab.
3. Click the **Add** button.
4. Enter `Production Schedule` in the **Display name** field.
5. Enter a description in the **Description** field. For example: `Endpoints for accessing the Production Schedule system.`
6. Check the **Published** and **Requires subscription** options.
7. Click the **Create** button.

### Step 21: Add the Production Schedule Facade to API Management

1. Go to the **APIs** tab.
2. Click the **+ Add API** button.
3. Click the **Function App** card.
4. Switch to **Full** view.
5. Next to the **Function App** field, click the **Browse** button.
6. Click the **Select** button.
7. Select the **func-ProductionScheduleFacade** function app and click the **Select** button.
8. Click the **Select** button in the lower-left corner.
9. Set the **Display name** to `Production Schedule`. The **Name** should automatically change to `production-schedule`.
10. Provide a **Description** for the API. For example, `Provides interaction with the Production Schedule system.`
11. Set the **API URL suffix** to `production-schedule`.
12. Select the **Production Schedule** product.
13. Click the Create button
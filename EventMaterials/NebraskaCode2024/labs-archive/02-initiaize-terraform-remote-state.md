[Design and Develop a Serverless Event-Driven Microservice-Based Solution](https://github.com/TaleLearnCode/EDAMicroserviceWorkshop) \ [Nebraska.Code 2024](README.md)  \ [Labs](README.md) \

# Lab 2: Creating Azure Resources with Terraform and Setup CI/CD

## Objective

Terraform uses **Terraform state** to determine which changes to make to your infrastructure. The state file keeps track of resources created by your configuration and maps to real-world resources. Before any operation, Terraform refreshes the state with the actual infrastructure. The primary purpose of the Terraform state is to store bindings between objects in a remote system and resource instances declared in your configuration.

By default, the Terraform state is stored locally. **Terraform remote state** allows you to store the state data in a remote data store, which can be shared among team members and/or automated processes.

In this lab, you will create the Terraform remote state to be used by you and your GitHub Actions or Azure DevOps Pipelines.

## Prerequisites

- Completion of  [Lab 1](01-initializing-solution.md) 
- Terraform installed on your local machine
- Azure CLI installed and authenticated on your local machine

## Steps

### Step 1: Initialize the remote state Terraform configuration project

1. Open Visual Studio Code.
2. Open the repository folder.
3. In the `infra` folder, create a `remote-state` folder.
4. In the `infra\remote-state` folder, create the `main.tf` file and add the following contents to the file:

```hcl
# #############################################################################
#                          Terraform Configuration
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
}

provider "azurerm" {
  skip_provider_registration = true
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

provider "local" {

}

# #############################################################################
#                          Modules
# #############################################################################

module "azure_regions" {
  source       = "git::https://github.com/TaleLearnCode/terraform-azure-regions.git"
  azure_region = var.azure_region
}

module "resource_group" {
  source        = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "resource-group"
}

module "storage_account" {
  source        = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "storage-account"
}


# #############################################################################
#                          Variables
# ############################################################################

variable "azure_region" {
	type        = string
	description = "Location of the resource group."
}

variable "azure_environment" {
	type        = string
	description = "The environment component of an Azure resource name. Valid values are dev, qa, e2e, core, and prod."
}

variable "resource_name_suffix" {
  type        = string
  default     = ""
  description = "The suffix to append to the resource names."
}

# #############################################################################
#                           Resource Name Suffix
# #############################################################################

resource "random_integer" "identifier" {
  min = 220
  max = 899
  keepers = {
    test_name = "${var.azure_environment}_${var.azure_region}"
  }
}

locals {
  resource_suffix = var.resource_name_suffix == "random" ? random_integer.identifier.result : var.resource_name_suffix
}

# #############################################################################
#                          Define the Tags
# #############################################################################

locals {
  criticality = var.azure_environment == "dev" ? "Medium" : var.azure_environment == "qa" ? "High" : var.azure_environment == "e2e" ? "High" : var.azure_environment == "prod" ? "Mission Critical" : "Medium"
  disaster_recovery = var.azure_environment == "dev" ? "Dev" : var.azure_environment == "qa" ? "Dev" : var.azure_environment == "e2e" ? "Dev" : var.azure_environment == "prod" ? "Mission Critical" : "Dev"
  tags = {
    Product      = "InfrastructureAsCode"
    Criticiality = local.criticality
    CostCenter   = "InfrastructureAsCode-${var.azure_environment}"
    DR           = local.disaster_recovery
    Env          = var.azure_environment
  }
}

# #############################################################################
#                       AzureRM Provider Configuration
# #############################################################################

data "azurerm_client_config" "current" {}

# #############################################################################
#                           Resource Group
# #############################################################################

resource "azurerm_resource_group" "rg" {
  name     = "${module.resource_group.name.abbreviation}-TerraformState${local.resource_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  location = module.azure_regions.region.region_cli
  tags     = local.tags
}

# #############################################################################
#                           Storage Account
# #############################################################################

resource "azurerm_storage_account" "st" {
  name                            = lower("${module.storage_account.name.abbreviation}Terraform${var.resource_name_suffix}${var.azure_environment}${module.azure_regions.region.region_short}")
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = false

  tags = local.tags
}

resource "azurerm_storage_container" "remote_state" {
  name                 = "terraform-state"
  storage_account_name = azurerm_storage_account.st.name
}

data "azurerm_storage_account_sas" "state" {
  connection_string = azurerm_storage_account.st.primary_connection_string
  https_only        = true

  resource_types {
    service   = true
    container = true
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  start  = timestamp()
  expiry = timeadd(timestamp(), "17520h")

  permissions {
    read    = true
    write   = true
    delete  = true
    list    = true
    add     = true
    create  = true
    update  = false
    process = false
    tag     = false
    filter  = false
  }
}

# #############################################################################
#                        Generate the TFConfig File
# #############################################################################

resource "local_file" "post-config" {
  depends_on = [azurerm_storage_container.remote_state]

  filename = "${path.module}/${var.azure_environment}.tfconfig"
  content  = <<EOF
storage_account_name = "${azurerm_storage_account.st.name}"
container_name = "terraform-state"
key = "iac.tfstate"
sas_token = "${data.azurerm_storage_account_sas.state.sas}"

  EOF
}
```

This Terraform configuration will perform the following actions (more details on the parts of a Terraform configuration will be provided in the next step):

- Initialize the Terraform providers used by the configuration.
- Initialize the Terraform modules used by the configuration.
- Initialize the variables used in the configuration.
- Generate a random resource name suffix (to help ensure resource names are globally unique).
- Define a local variable to represent the Azure resource tags.
- Get a reference to the user executing the Terraform configuration.
- Create an Azure resource group to house the Terraform state resources.
- Create the Azure Storage account that Terraform will use to store its state.
- Create a `remote-state` storage container to house the Terraform state file.
- Create an SAS token to be used to access the storage account locally.
- Generate a TFConfig file containing the authentication information for locally connecting to the Terraform state storage account.

> TFConfig is not a standard defined by Hashicorp or anyone other than Chad Green. It is what he has used to help distinguish this file.

5. Open a Terminal window to execute the Terraform configuration project.
   - In Visual Studio code, click on the `Terminal` menu item and then select the `New Terminal Window` option.
6. From the Terminal window you just opened, connect to your Azure account.

```sh
az login
```

Follow the prompts to log into your Azure account and select the appropriate subscription (if you have multiple subscriptions).

7. Initialize the Terraform configuration project:

```hcl
terraform init
```

8. Validate that the Terraform configuration project is syntactically correct:

```hcl
terraform validate
```

Correct any validation errors (there should not be any).

9. Plan the Terraform configuration project:

```hcl
terraform plan -var 'azure_environment=dev' -var 'azure_region=centralus' -var 'resource_name_suffix=random'  
```

There are three variables being defined in the `terraform plan` command:

- **azure_environment**: This is the system environment (i.e. dev, qa, stage, prod, etc.) you are deploying to. Multiple deployment environments are out of scope for this workshop, but we are simulating that we are deploying to `dev` since that would generally be the first environment to deploy to.
- **azure_environment**: This is the name of the Azure region where Azure resources are deployed. As is the case when creating Azure resources, you should pick the region closest to the target users. In the command above, `centralus` has been specified since that is the closest Azure region to Lincoln, NE.
- **resource_name_suffix**: This Terraform configuration project can use a random generator to help ensure the created resources are globally unique. Specifying `random` will ensure that a three-digit random number is added to the end of the resource names. You can also select anything else you want or leave the value blank; no suffix will be added.

> [!NOTE]
>
> The `azure_environment` and `resource_name_suffix` values together cannot be longer than **13** characters. Azure Storage accounts are limited to **24** characters, and the resource name's static part uses **11** of those characters.

>  [!NOTE] 
>
>  While the `terraform validate` command lints the configuration, the terraform plan can find additional syntactical issues that must be resolved.

Review the outputted plan to ensure what was expected to be built will be built.

10. Apply the Terraform configuration project to Azure:

``` hcl
terraform apply -var 'azure_environment=dev' -var 'azure_region=centralus' -var 'resource_name_suffix=random'
```

- Review the outputted plan to ensure what was expected to be built will be built.
- If the plan looks correct, type `yes` to apply the configuration to your Azure account.

After the apply is done, you should see the following at the end of the output:

```hcl
Apply complete! Resources: 5 added, 0 changed, 0 destroyed.
```

### Step 2: Ignore the TFConfig files

The `TFConfig` generated in step one contains secrets (the SAS token to access the recently created storage account). As such, that file should not be checked into your Git repository.

1. In Visual Studio Code, open the .gitignore file in the root directory of the repository folder.
2. Add the following somewhere in the .gitignore file:

```yml
# Ignore TFConfig files
*.tfconfig

# Ignore Terraform lock files
.terraform.lock.hcl
```

### Step 3: Push the remote state Terraform project to your central Git repository

1. Click on the `Source Control` tab within Visual Studio code.
2. Add an appropriate commit message:

```
Adding the Terraform remote state configuration project.
```

3. Click the **Commit** button (this will perform a `git commit` command).
4. Click the **Sync Changes** button (this will perform a `git push` command).

## Conclusion

You have now used Terraform to create the Azure resources needed to implement Terraform's remote state.

## Next Steps

In the next lab, we will create the core Azure resources used across the Cool Revive Remanufacturing system.
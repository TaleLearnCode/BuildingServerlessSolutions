[Design and Develop a Serverless Event-Driven Microservice-Based Solution](https://github.com/TaleLearnCode/EDAMicroserviceWorkshop) \ [Nebraska.Code 2024](README.md)  \ [Labs](README.md) \

# Lab 6: Create Terraform Module for Secret Management

## Objective

Managing an Azure Function with Terraform requires several configuration elements. An App Service Plan, Azure Storage account, and the Azure Function app must be created. If you want to use virtual network integration with Azure Functions, quite a bit more must be configured (we will not use) virtual networking in this workshop). If you need to create multiple Azure Function apps (such as we will in this workshop), this means a lot of boilerplate and duplicated configuration.

To ease this for the Cool Revive DevOps team, we will create a custom module that will encapsulate the configuration and can be used each time we need to create a Flex Consumption Azure Function.

## Prerequisites

- Completion of [Lab 5](05-azure-function-module.md).
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
git branch features/06-app-config-secret-module
```

5. Checkout the feature branch for the lab:

```sh
git checkout features/06-app-config-secret-module
```

### Step 2: Create the folder for the module

1. Create the `infra\modules\app-config-secret` folder.

### Step 3: Create the variables file

1. In the `infra\modules\app-config-secret` folder, create a file named `variables.tf`, and add the following configuration:

```HCL
variable "app_config_label" {
  type        = string
  description = "The label to apply to the App Configuration"
}

variable "app_config_key" {
  type        = string
  description = "The key to create in the App Configuration store"
}

variable "configuration_store_id" {
  type        = string
  description = "The ID of the App Configuration store to create the key in"
}

variable "key_vault_id" {
  type        = string
  description = "The ID of the Key Vault to create the secret in"
}

variable "secret_name" {
  type        = string
  description = "The name of the secret to create in the Key Vault"
}

variable "secret_value" {
  type        = string
  description = "The value of the secret to create in the Key Vault"
}
```

### Step 4: Create the main file

1. In the `infra\modules\app-config-secret` folder, create a file named `main.tf`, and add the following configuration:

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
# Key Vault Secret
# #############################################################################

resource "azurerm_key_vault_secret" "secret" {
  name         = var.secret_name
  value        = var.secret_value
  key_vault_id = var.key_vault_id
}

# #############################################################################
# App Config Key/Value Pair
# #############################################################################

resource "azurerm_app_configuration_key" "app_config" {
  configuration_store_id = var.configuration_store_id
  key                    = var.app_config_key
  type                   = "vault"
  label                  = var.app_config_label
  vault_key_reference    = azurerm_key_vault_secret.secret.versionless_id
  lifecycle {
    ignore_changes = [
      value
    ]
  }
}
```

In this file, we have the following configuration elements:

- **Required Providers**: This instructs projects using this module what Terraform providers the module requires. For this module, we require `azurerm` (Azure).
- **Key Vault Secret**: This manages the Key Vault secret where the sensitive value is stored.
- **App Config Key/Value Pair**: This manages the App Config store key/value pair to easily access the secret value.

### Step 5: Create the output file

One of the nice parts of Terraform modules is that we can pass information back to the primary Terraform project. These are done using the `output` Terraform element.

1. In the `infra\modules\app-config-secret` folder, create a file named `outputs.tf`, and add the following configuration:

```HCL
output "key" {
  value = azurerm_app_configuration_key.app_config.key
}

output "label" {
  value = azurerm_app_configuration_key.app_config.label
}
```

In this module, we return the name key and label of the App Config store key/value pair.

### Step 6: Commit and push the Terraform project to your central Git repository

1. Click on the `Source Control` tab within Visual Studio code.
2. Add an appropriate commit message:

```
Adding the App Config Secret module.
```

3. Click the **Commit** button (this will perform a `git commit` command).
4. Click the **Publish Branch** button.

### Step 7: Create a pull request and merge it into develop

#### Using GitHub

1. Navigate to your GitHub repository.
2. Click the **Pull requests** tab.
3. Click the **New pull request** button.
4. Change the **compare** to `features/06-app-config-secret-module`.
5. Click the **Create pull request** button.
6. Click the **Create pull request** button.
7. Once all of the checks have passed, click the **Merge pull request** button.
8. Click the **Confirm merge** button.
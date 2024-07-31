[Design and Develop a Serverless Event-Driven Microservice-Based Solution](https://github.com/TaleLearnCode/EDAMicroserviceWorkshop) \ [Nebraska.Code 2024](README.md)  \ [Labs](README.md) \

# Lab 3: Prepare for CI/CD Pipelines

## Objective

While you can apply Terraform configuration projects locally, there are many benefits to setting up continuous integration/continuous development (CI/CD) pipelines to handle this task automatically when you push changes into the repository. Those CI/CD pipelines will need an Azure service principal to act under, and we will create that in this lab. We will also be initializing secrets that the pipelines will use.

## Prerequisites

- Completion of  [Lab 2](02-initiaize-terraform-remote-state.md) 
- Terraform installed on your local machine
- Azure CLI installed and authenticated on your local machine

## Steps

### Step 1: Create an Azure service principal for the CI/CD pipelines to use

In a future lab, we will set up continuous integration/continuous development (CI/CD) pipelines to deploy Azure infrastructure changes when the Terraform configuration changes. GitHub/Azure DevOps will require an Azure service principal to execute the Terraform apply command to your Azure subscription.

1. Open a terminal or command prompt.
2. Log in to your Azure account:

``` sh
az login
```

- Follow the instructions to log in. If you using a cloud shell, this step is not needed.

3. Create a service principal:

```sh
az ad sp create-for-rbac --name "TerraformServicePrincipal" --role Contributor --scopes /subscriptions/YOUR_SUBSCRIPTION_ID
```

- Replace `YOUR_SUBSCRIPTION_ID` with your actual Azure subscription identifier.
- This command will output a JSON object containing the necessary credentials.

Here is an example of what the JSON output might look like:

```json
{
  "appId": "YOUR_APP_ID",
  "displayName": "myServicePrincipal",
  "password": "YOUR_PASSWORD",
  "tenant": "YOUR_TENANT_ID"
}
```

Save the outputted JSON somewhere for future use.

> [!CAUTION] 
>
> Do not save the outputted JSON in your Git repository. This contains secrets that should not be stored in a repository.

### Step 2: Add service principal to GitHub or Azure DevOps

#### Using GitHub

1. Navigate to your GitHub repository.

2. Go to the **Settings** tab.

3. Select "**Secrets and variables**" from the sidebar and click **Actions**.

4. Click on the "**New repository secret**" button.

5. Add a secret named `AZURE_CREDENTIALS`

   - Paste the outputted JSON from the previous step into the **Value** field.

   - Create a value based upon the outputted JSON from the previous set in to **Value** field as such:

     ``` json
     {
         "clientSecret":  "'password' from above",
         "subscriptionId":  "YOUR_SUBSCRIPTION_ID",
         "tenantId":  "'tenant' from above",
         "clientId":  "'appId' from above"
     }
     ```

   - Click "**Add secret**".

#### Using Azure DevOps

1. Navigate to your Azure DevOps project
2. Go to "**Project settings**".
3. Go to "**Service connections**".
4. Depending on whether you already have a service connection or not, perform one of these options:
   - If there are no service connections, click the "**Create service connection**" button.
   - If there are already service connections, click the "**New service connection**" button.
5. Select "**Azure Resource Manager**" and click the **Next** button.
6. Select "**Service principal (manual)**" and click the **Next** button.
7. Fill in the details from the service principal output from the previous step:
   - Subscription Id: Your Azure subscription ID
   - Subscription Name: Your Azure subscription name
   - Service Principal Id: `appId` from the JSON
   - Credential: Service principal key
   - Service Principal Key: `password` from the JSON
   - Tenant ID: `tenant` from the JSON.
8. Click the **Verify** button.
9. Name the service connection (e.g. `my-azure-service-connection`) and click "**Verify and save**".

### Step 3: Add Secrets

To connect to the Terraform remote state, the `terraform init` command will need details on the storage account, including the storage account key. We do not want that key in plain text in the repository, so we will add a secret.

#### Using GitHub

1. The GitHub Action pipeline we will build in [Lab 5](05-create-terraform-pipeline.md) will depend on several secret values.

1. Navigate to your GitHub repository.
2. Go to the **Settings** tab.
3. Select "**Secrets and variables**" from the sidebar and click **Actions**.
4. For each of the secrets listed below, do the following: click on the "**New repository secret**" button, enter the specified secret name, enter the specified secret value, and click the "**Add secret**" button.

| Secret Name                    | Secret Value                                                 |
| ------------------------------ | ------------------------------------------------------------ |
| AZURE_AD_CLIENT_ID             | The `app-id` value returned when creating the service principal. |
| AZURE_AD_CLIENT_SECRET         | The `password` value returned when creating the service principal. |
| AZURE_SUBSCRIPTION_ID          | Your subscription identifier.                                |
| AZURE_AD_TENANT_ID             | The `tenant` value returned when creating the service principal. |
| TERRAFORM_STORAGE_ACCOUNT_NAME | Name of the storage account created in [Lab 2](02-initiaize-terraform-remote-state.md) |
| TERRAFORM_RESOURCE_GROUP       | Name of the resource group created in [Lab 2](02-initiaize-terraform-remote-state.md) |

#### Using Azure DevOps

1. Navigate to your Azur DevOps project.
2. Go to **Pipelines** > **Library**.
3. Click the "**+ Variable group**" button.
4. Name the variable group `Terraform-Remote-State`.
5. Click the "**+ Add**" button, add a secret named `TERRAFORM_STORAGE_ACCOUNT_NAME`, and enter the name of the storage account created in [Lab 2](02-initiaize-terraform-remote-state.md) for the value.
6. Click the "**+ Add**" button, add a secret named `TERRAFORM_STORAGE_ACCOUNT_KEY`, and enter the `sas_token` value from the tfconfig generated in [Lab 2](02-initiaize-terraform-remote-state.md) for the value.
7. Click the **Save** button.

> [!TIP]
>
> Notice that the variable group can be linked to an Azure Key Vault. This is generally the best practice so that the secrets can be managed there, and you only have one place to update them if/when they need changing.



## Conclusion

In this lab, you have created an Azure service principal and configured your software development platform (GitHub or Azure DevOps) to use it.

## Next Steps

In the next lab, we will create the core Azure resources used across the Cool Revive Remanufacturing system and add the pipeline to deploy those resources.
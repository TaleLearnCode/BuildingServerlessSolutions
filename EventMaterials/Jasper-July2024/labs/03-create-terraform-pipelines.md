[Design and Develop a Serverless Event-Driven Microservice-Based Solution](https://github.com/TaleLearnCode/EDAMicroserviceWorkshop) \ [Nebraska.Code 2024](README.md)  \ [Labs](README.md) \

# Lab 3: Create Terraform pipelines

## Objective

While you can apply Terraform configuration projects locally, there are many benefits to setting up continuous integration/continuous development (CI/CD) pipelines to handle this task automatically when you push changes into the repository. We will create the CI and CD Terraform pipelines for your workshop project in this lab.

## Prerequisites

- Completion of  [Lab 2](02-initiaize-terraform-remote-state.md) 
- Terraform is installed on your local machine.
- Azure CLI installed and authenticated on your local machine

## Steps

### Step 1: Create an Azure service principal for the CI/CD pipelines to use

In a future lab, we will set up continuous integration/continuous development (CI/CD) pipelines to deploy Azure infrastructure changes when the Terraform configuration changes. GitHub/Azure DevOps will require an Azure service principal to execute the Terraform apply command to your Azure subscription.

1. Open a terminal or command prompt.
2. If not already logged into your Azure account, log in to your Azure account:

``` sh
az login
```

- Follow the instructions to log in. This step is not needed if you are using a cloud shell.

3. Get your Azure subscription identifier:

```sh
az account show
```

This will return several pieces of information about your Azure subscription. Please take note of the `ID` value, as you will need it in the next step.

4. Create a service principal:

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

5. Add a secret named `AZURE_CREDENTIALS`.

   - Paste the outputted JSON from the previous step into the **Value** field.

   - Create a value based upon the outputted JSON from the previous set in the **Value** field as such:

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

1. Navigate to your Azure DevOps project.
2. Go to "**Project settings**".
3. Go to "**Service connections**".
4. Depending on whether you already have a service connection or not, perform one of these options:
   - If there are no service connections, click the "**Create service connection**" button.
   - If there are already service connections, click the "**New service connection**" button.
5. Select "**Azure Resource Manager**" and click the **Next** button.
6. Select "**Service principal (manual)**" and click the **Next** button.
7. Fill in the details from the service principal output from the previous step:
   - Subscription ID: Your Azure subscription ID
   - Subscription Name: Your Azure subscription name
   - Service Principal Id: `appId` from the JSON
   - Credential: Service principal key
   - Service Principal Key: `password` from the JSON
   - Tenant ID: `tenant` from the JSON.
8. Click the **Verify** button.
9. Name the service connection (e.g., `my-azure-service-connection`) and click "**Verify and save**".

### Step 3: Permit the service principal to assign roles

1. Go to the [Azure Portal](https://portal.azure.com).
2. Click on **Subscriptions**.
3. Click on the subscription you are working with for the workshop.
4. Click on **Access control (IAM)**.
5. In the **Create a custom role** card, click the **Add** button.
6. Enter `Terraform Service Principal` in the **Custom role name** field.
7. Click the **Next** button.
8. Click the **Add permissions** button.
9. Search for `Microsoft.Authorization/roleAssignments`. Click the **Microsoft Authorization** card.
10. Select all three (Read, Write, Delete) permissions under **Microsoft.Authozization/roleAssignments**.
11. Click the **Add** button.
12. Go to the **Review + create** tab.
13. Click the **Create** button.
14. After returning to the **Access control (IAM)** page, click **Add** > **Add role assignment**.
15. Go to the **Privileged administrator roles** tab.
16. Select **Terraform Service Principal** and click the **Next** button.
17. With the **User, group, or service principal** option selected, click the **+ Select members** link.
18. Search for and select `TerraformServicePrincipal` and click the **Select** button.
19. Click the **Next** button.
20. ON the **Conditions** tab, select **Allow user to assign all roles except privileged administrator roles Owner, RBAC (Recommended)**.
21. Click the **Review + assign** button.
22. Click the **Review + assign** button (again).

### Step 3: Add Secrets

To connect to the Terraform remote state, the `terraform init` command will need details on the storage account, including the storage account key. We do not want that key in plain text in the repository, so we will add a secret.

#### Using GitHub

1. The GitHub Action pipeline we will build in [Lab 5](05-create-terraform-pipeline.md) will depend on several secret values.

2. Navigate to your GitHub repository.
3. Go to the **Settings** tab.
4. Select "**Secrets and variables**" from the sidebar and click **Actions**.
5. For each of the secrets listed below, do the following: click on the "**New repository secret**" button, enter the specified secret name, enter the specified secret value, and click the "**Add secret**" button.

| Secret Name                    | Secret Value                                                 |
| ------------------------------ | ------------------------------------------------------------ |
| AZURE_AD_CLIENT_ID             | The `app-id` value returned when creating the service principal. |
| AZURE_AD_CLIENT_SECRET         | The `password` value is  returned when creating the service principal. |
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

### Step 4: Create the CI infrastructure pipeline

**Continuous Integration (CI)** is the practice of automating the integration of code changes from multiple contributors into a single software project. It allows developers to frequently merge code changes into a central repository, where builds and tests are run. Validation pipelines are critical when applying CI practices to ensure someone does not accidentally push something to the repository that breaks the build.

#### Using GitHub

1. In Visual Studio Code, create a folder named `.github\workflows`.
2. In the `.github\workflows` folder, create a file named `ci.yml` and add the following to the file:

```yaml
name: Continuous Integration

on:
  pull_request:
    branches:
      - develop
    paths:
      - 'infra/**'
      - 'src/**'

jobs:
  paths-filter:
    runs-on: ubuntu-latest
    outputs:
      terraform: ${{ steps.filter.outputs.terraform }}
      production-schedule-facade: ${{ steps.filter.outputs.production-schedule-facade }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            terraform:
              - 'infra/**'

  terraform:
    name: 'Terraform CI'
    needs: paths-filter
    env:
      ARM_CLIENT_ID: ${{ secrets.AZURE_AD_CLIENT_ID }}
      ARM_CLIENT_SECRET: ${{ secrets.AZURE_AD_CLIENT_SECRET }}
      ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      ARM_TENANT_ID: ${{ secrets.AZURE_AD_TENANT_ID }}
    runs-on: ubuntu-latest
    defaults:
      run:
        shell: bash
    if: needs.paths-filter.outputs.terraform == 'true'
    steps:
      # Checkout the repository to the GitHub Actions runner
      - name: Checkout
        uses: actions/checkout@v4
  
      # Install the latest version of Terraform
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v1
  
      # Initialize the Terraform project
      - name: Terraform Init
        run: terraform init -backend-config="resource_group_name=${{ secrets.TERRAFORM_RESOURCE_GROUP }}" -backend-config="storage_account_name=${{ secrets.TERRAFORM_STORAGE_ACCOUNT_NAME }}" -backend-config="container_name=terraform-state" -backend-config="key=remanufacturing.tfstate"
        working-directory: ./infra
  
      # Validate the Terraform configuration
      - name: Terraform Validate
        run: terraform validate
        working-directory: ./infra
  
      # Generate and show an execution plan
      - name: Terraform Plan
        run: terraform plan --var-file=dev.tfvars
        working-directory: ./infra
```

### Step 5: Create the CD infrastructure pipeline

**Continuous Deployment (CD)** is a software development approach in which application code changes are automatically deployed into the target environment. In this step, we will create the pipeline to publish infrastructure changes automatically once they are pushed into the repository.

1. In the `.github\workflows` folder, create a file named `cd.yml` and add the following to the file:

```yaml
name: Continuous Deployment

on:
  push:
    branches:
      - develop
    paths:
      - 'infra/**'
      - 'src/**'

jobs:
  paths-filter:
    runs-on: ubuntu-latest
    outputs:
      terraform: ${{ steps.filter.outputs.terraform }}
      production-schedule-facade: ${{ steps.filter.outputs.production-schedule-facade }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            terraform:
              - 'infra/**'

  terraform:
    name: 'Terraform CI'
    needs: paths-filter
    env:
      ARM_CLIENT_ID: ${{ secrets.AZURE_AD_CLIENT_ID }}
      ARM_CLIENT_SECRET: ${{ secrets.AZURE_AD_CLIENT_SECRET }}
      ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      ARM_TENANT_ID: ${{ secrets.AZURE_AD_TENANT_ID }}
    runs-on: ubuntu-latest
    defaults:
      run:
        shell: bash
    if: needs.paths-filter.outputs.terraform == 'true'
    steps:
      # Checkout the repository to the GitHub Actions runner
      - name: Checkout
        uses: actions/checkout@v4
  
      # Install the latest version of Terraform
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v1
  
      # Initialize the Terraform project
      - name: Terraform Init
        run: terraform init -backend-config="resource_group_name=${{ secrets.TERRAFORM_RESOURCE_GROUP }}" -backend-config="storage_account_name=${{ secrets.TERRAFORM_STORAGE_ACCOUNT_NAME }}" -backend-config="container_name=terraform-state" -backend-config="key=remanufacturing.tfstate"
        working-directory: ./infra
  
      # Validate the Terraform configuration
      - name: Terraform Validate
        run: terraform validate
        working-directory: ./infra
  
      # Generate and show an execution plan
      - name: Terraform Plan
        run: terraform plan --var-file=dev.tfvars -out=tfplan
        working-directory: ./infra
  
      - name: Terraform Apply
        run: terraform apply -auto-approve tfplan
        working-directory: ./infra
```

### Step 6: Commit and push changes to the central Git repository

1. Click on the `Source Control` tab within Visual Studio code.
2. Add an appropriate commit message:

```
Adding infrastructure pipelines.
```

3. Click the **Commit** button (this will perform a `git commit` command).
4. Click the **Sync Changes** button (this will perform a `git push` command).

### Step 7: Protect the branches

#### Using GitHub

1. Navigate to your repository's settings.
2. Click on **Branches**.
3. Click the **Add branch ruleset** button.
4. Give your the ruleset a name in the **Ruleset Name** field.
5. Set the **Enforcement status** to **Active**.
6. In the *Target branches* section, click the **Add target** button, click **Include by pattern**, enter `main` in the **Branch naming pattern** field, and click the **Add Inclusion pattern** button.
7. In the **Target branches** section, click the **Add target** button, click **Include by pattern**, enter `develop` in the **Branch naming pattern** field, and click the **Add Inclusion pattern** button.
8. Under the *Branch protections* section, ensure that **Restrict deletions** and **Block force pushes** are checked.
9. Under the *Branch protections* section, check **Require a pull request before merging**.

> [!NOTE]
>
> We are not requiring approvals (Required approvals = 0), but in a real-world scenario you would want to configure to require at least one approval.

10. Click the **Create** button.

> [!NOTE]
>
> From here on out, you will need to create feature branches off of the develop branch and then perform pull requests to merge changes into the `develop` branch.



## Conclusion

In this lab, you have created an Azure service principal and configured your software development platform (GitHub or Azure DevOps) to use it.

## Next Steps

In the next lab, we will create the core Azure resources used across the Cool Revive Remanufacturing system and add the pipeline to deploy those resources.
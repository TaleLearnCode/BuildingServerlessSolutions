[Design and Develop a Serverless Event-Driven Microservice-Based Solution](https://github.com/TaleLearnCode/EDAMicroserviceWorkshop) \ [Nebraska.Code 2024](README.md)  \ [Labs](README.md) \

# Lab 5: Create Terraform Pipeline

Now that we have built a Terraform configuration project, we must create the pipeline to automatically apply those changes when they are merged with the development branch.

## Prerequisites

- Completion of  [Lab 4](04-create-core-azure-resources.md) 
- Terraform installed on your local machine
- Azure CLI installed and authenticated on your local machine

## Steps

### Step 1: Create the Terraform Pipeline

#### Using GitHub

1. In Visual Studio Code, create a folder named `.github\workflows`
2. In the `.github\workflows` folder, create a file named `terraform.yml` and add the following to the file:

```
name: Terraform

on:
  push:
    branches:
      - develop

jobs:
  terraform:
    name: 'Terraform'
    env:
      ARM_CLIENT_ID: ${{ secrets.AZURE_AD_CLIENT_ID }}
      ARM_CLIENT_SECRET: ${{ secrets.AZURE_AD_CLIENT_SECRET }}
      ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      ARM_TENANT_ID: ${{ secrets.AZURE_AD_TENANT_ID }}
    runs-on: ubuntu-latest

    defaults:
      run:
        shell: bash

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

    # Generate and show an execution plan
    - name: Terraform Plan
      run: terraform plan -out=tfplan
      working-directory: ./infra

    - name: Terraform Apply
      run: terraform apply -auto-approve tfplan
      working-directory: ./infra
```

> [!TIP]
>
> In this workshop, we are only creating a CD pipeline. In a real-world scenario, creating a separate CI pipeline that validates that the Terraform configuration is valid before allowing a pull request to be merged is a good practice.

### Step 2: Commit and push changes to the central Git repository

1. Click on the `Source Control` tab within Visual Studio code.
2. Add an appropriate commit message:

```
Adding Terraform CD pipeline.
```

3. Click the **Commit** button (this will perform a `git commit` command).
4. Click the **Sync Changes** button (this will perform a `git push` command).

### Step 3: Validate that the pipeline is working

#### Using GitHub

1. Navigate to your GitHub repository.
2. Click on the **Actions** tab.
3. Click on the running `Terraform` action; correct any errors, if any.

## Conclusion

You have now used Terraform with remote state to create the core Azure resources for the *Cool Revive Technologies Remanufacturing* system and set up CI/CD pipelines using Azure DevOps Pipelines or GitHub Actions to deploy that infrastructure to Azure.

## Next Steps

In the next lab, we will create the **Order Next Core** microservice.


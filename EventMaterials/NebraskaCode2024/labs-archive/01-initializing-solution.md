[Design and Develop a Serverless Event-Driven Microservice-Based Solution](https://github.com/TaleLearnCode/EDAMicroserviceWorkshop) \ [Nebraska.Code 2024](README.md)  \ [Labs](README.md) \

# Lab 1: Initializing Solution

## Objective

Set up a Git repository for the Cool Revive Technologies remanufacturing process solution using either GitHub or Azure DevOps, and prepare your development environment.

> [!NOTE]
>
> The Cool Revive Technologies solution implements a microservice-based architecture. For the purpose of the workshop lab, we will create one repository and one Visual Studio solution that will contain all of the microservices. In reality, you will want to split out the microservices to be independent of each other.



## Prerequisites

- Git installed on your local machine.
- A GitHub account or an Azure DevOps account.
- Visual Studio or Visual Studio Codec installed on your local machine.

## Steps

### Step 1: Create a Repository

Use either the [Using GitHub](#using-github) or [Using Azure DevOps](#using-azure-devops) option, depending on your preferred toolset.

#### Using GitHub

1. Sign in to GitHub:
   - Go to [GitHub](https://github.com/) and sign in with your GitHub account.
2. Create a new repository.
   - Click on the **+** icon in the upper-right corner and select **New repository**.
   - Provide a name of the repository (e.g. `cool-revive-remanufacturing`).
   - Add a description (optional).
   - Choose whether the repository is public or private.
   - Do not initialize the repository with a README, .gitignore, or license (we will add these later).
   - Click on the **Create repository** button.

#### Using Azure DevOps

1. Sign in to Azure DevOps
   - Go to [Azure DevOps](https://dev.azure.com/) and sign in with your Azure DevOps account.
2. Create a new project
   - Click on the **+ New project** button.
   - Enter the project name (e.g. `CoolReviveRemanufacturing`).
   - Add a description (optional).
   - Choose whether the project is public or private.
   - Click on the **Create** button.
3. Create a Git repository
   - Navigate to the **Repos** section in the newly created project.
   - Click the **Initialize** button to create the repository.

### Step 2: Clone the Repository to Your Local Machine

#### Using GitHub

1. Get the repository URL:

   - On your GitHub repository page, copy the HTTPS URL.

2. Clone the repository:

   ```sh
   git clone https://github.com/YOUR-USERNAME/cool-revive-remanufacutring.git
   cd cool-revive-remanufacturing
   ```

>  [!NOTE]
>
> You will likely receive a warning that you have cloned an empty repository. This is correct because we have not put anything in the repository yet.

#### Using Azure Dev

1. Get the repository URL:

   - On your Azure DevOps repository page, click the **Clone** button and copy the HTTPS URL.

2. Clone the repository:

   ```sh
   git clone https://dev.azure.com/YOUR-ORGANIZATION/CoolReviveRemanufacturing/_git/CoolReviveRemanufacturing
   cd CoolReviveRemanufacturing
   ```

### Step 3: Add the LICENSE file

1. Choose a license suitable for your project from [choosealicense.com](https://choosealicense.com/).
2. Copy the text for the chosen license.
3. Create and open the LICENSE file:

```sh
code LICENSE
```

4. Paste the license text into the LICENSE and make any necessary updates.
5. Save the file and close Visual Studio Code.
6. Add the file to the git tracking for the repository:

```sh
git add LICENSE
```

### Step 4: Initialize the README.md file

1. Create and open the README.md file:

```sh
code README.md
```

2. Paste the following contents into the README.md file:

```markdown
# Cool Revive Technologies Remanufacturing Solution
This repository contains source code and configuration for the Cool Revive Technologies Remanufacturing Solution as part of the [Deisgn and Devleop and Develop a Serverless Event-Driven Microserice-Based Solution](https://github.com/TaleLearnCode/DesignDevelopServerlessEventDrivenMicroserviceSolution) workshop at [Nebraska.Code](https://nebraskacode.amegala.com/) presented by [Chad Green](https://chadgreen.com).

## Microservices
As microservices are added to the solution, details of those will be added here.
```

> [!NOTE]
>
> If using Azure DevOps, the README.md file generated by Azure DevOps will have default text. Just paste over the generated text.

3. If using GitHub, add the file to the git tracking for the repository:

```sh
git add README.md
```

### Step 5: Generate a .gitignore File

1. Go to the Topal GitIgnore Generator:
   - Open your browser and go to the [Topal Gitignore Generator](https://gitignore.io/).

2. Select the tools and environments to determine appropriate ignores:
   - Type and select `VisualStudio`, `VisualStudioCode`, and `Terraform` in the search bar.
3. Generate the .gitignore file:
   - Click on "Create" to generate the .gitignore file.
4. Copy the generated .gitignore file contents.
5. Create and open the .gitignore file:

```sh
code .gitignore
```

6. Paste the .gitignore content into the file and save it. You can now close Visual Studio Code.

7. Add the .gitignore file to your repository:

- Move the downloaded `.gitignore` file to your cloned repository directory.

2. Add the .gitignore file to the git tracking:

   ```sh
   git add .gitignore
   ```

### Step 6: Initialize project structure

As we build our solution, we will need a place to store our source code and infrastructure configuration.

1. Create the source folder:

```sh
md src
cd src
echo "Source" > README.md
git add README.md
```

2. Create the infrastructure folder:

```sh
cd ..
md infra
cd infra
echo "Infrastructure" > README.md
git add README.md
```

> [!NOTE]
>
> We will add details to the readme files later. Adding these files now will allow the folder to be displayed in git, as git does not show empty folders.

### Step 7: Commit and push the initial repository structure

1. Commit and push the initial repository structure to the git repository:

```sh
git commit -m "Initializing repository structure."
git push origin main
```

### Step 8: Create and switch to the develop branch

1. Create and switch to the develop branch:

```sh
git checkout -b develop
```

2. Push the develop branch to the remote repository:

```sh
git push -u origin develop
```

### Step 9: Set the develop branch as the default branch

#### Using GitHub

- Navigate to your repository on GitHub.

- Click on the **Settings** tab.
- In the *Default branch* section, change the default branch to `develop`.

#### For Azure DevOps

- Navigate to your repository in Azure DevOps
- Click on "Repos" > "Branches"
- Find the `develop` branch and click on the **More options** (three dots) button.
- Select the **Set as default branch** menu item.

## Conclusion

You have now created a Git repository, cloned it to our local machine, set up a .gitignore file, created a `develop` branch, and set it as the default branch. You are ready to start developing the solution for Cool Revive Technologies' remanufacturing processes using Azure and .NET!

## Next Steps

In the next lab, we will set up the Azure resource group we will be using throughout this workshop along with a storage account to store Terraform's state.
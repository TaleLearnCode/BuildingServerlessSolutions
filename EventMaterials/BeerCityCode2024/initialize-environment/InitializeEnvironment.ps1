 param (
    [string]$TargetPath,
    [string]$GitHubToken,
    [string]$APIMPublisherEmail,
    [string]$APIMPublisherName = "Cool Revive Technologies",
    [string]$GitHubRepoName = "cool-revive",
    [string]$AzureRegion = "eastus2"
)

# Save the current directory
$originalPath = Get-Location

# Prompt for missing input parameters
if (-not $TargetPath) {
    $TargetPath = Read-Host "Please enter the target path"
}
if (-not $GitHubToken) {
    $GitHubToken = Read
}
if (-not $APIMPublisherEmail) {
    $APIMPublisherEmail = Read
  }

# Validate that the $TargetPath is a valid path
if (-not (Test-Path -Path $TargetPath)) {
    Write-Error "The target path '$TargetPath' does not exist"
    exit 1
}

# #############################################################################
# Generate a random suffix for Azure resources
# #############################################################################

$randomNumber = Get-Random -Minimum 1 -Maximum 1000
$RandomNameSuffix = $randomNumber.ToString("D3")

# #############################################################################
# Build the local repository direcotry structure
# #############################################################################

Write-Host ""
Write-Host ""
Write-Host ""
$originalColor = $Host.UI.RawUI.ForegroundColor
$Host.UI.RawUI.ForegroundColor = "Cyan"
Write-Host "-------------------------------------------------------------------------------"
Write-Host "Building the local repository directory structure..."
Write-Host "-------------------------------------------------------------------------------"
$Host.UI.RawUI.ForegroundColor = $originalColor

# Build the local repository directory structure
$folderStructure = @(
    "cool-revive",
    "cool-revive\.github",
    "cool-revive\.github\workflows",
    "cool-revive\infra",
    "cool-revive\infra\github",
    "cool-revive\infra\remote-state",
    "cool-revive\infra\service-principal",
    "cool-revive\infra\solution",
    #"cool-revive\infra\solution\apim",
    #"cool-revive\infra\solution\remanufacturing\",
    #"cool-revive\infra\solution\remanufacturing\core",
    #"cool-revive\infra\solution\remanufacturing\ordernextcore",
    "cool-revive\src",
    "cool-revive\src\core",
    "cool-revive\src\getnextcore",
    "cool-revive\src\getnextcorehandler",
    "cool-revive\src\inventorymanagement"
)
foreach ($folder in $folderStructure) {
    $fullPath = Join-Path -Path $TargetPath -ChildPath $folder
    if (-not (Test-Path -Path $fullPath)) {
        New-Item -Path $fullPath -ItemType Directory
    }
}

# #############################################################################
# Initialize the GitHub repository
# #############################################################################

Write-Host ""
Write-Host ""
Write-Host ""
$originalColor = $Host.UI.RawUI.ForegroundColor
$Host.UI.RawUI.ForegroundColor = "Cyan"
Write-Host "-------------------------------------------------------------------------------"
Write-Host "Initializing the GitHub repository..."
Write-Host "-------------------------------------------------------------------------------"
$Host.UI.RawUI.ForegroundColor = $originalColor

# Copy files from initialize-GitHub folder to the target GitHub folder
$sourcePath = Join-Path -Path $PSScriptRoot -ChildPath "initialize-github"
$destinationPath = Join-Path -Path $TargetPath -ChildPath "cool-revive\infra\github"
Copy-Item -Path $sourcePath\* -Destination $destinationPath -Recurse -Force

# Create the github.tfconfig file
$tfconfigPath = Join-Path -Path $destinationPath -ChildPath "github.tfconfig"
"gitHub_token = $GitHubToken" | Out-File -FilePath $tfconfigPath -Force

# Execute Terraform commands
Set-Location -Path $destinationPath
#cd $destinationPath
$commands = @(
    @{ Command = "terraform init"; Message = "Initializing Terraform..." },
    @{ Command = "terraform validate"; Message = "Validating Terraform configuration..." },
    @{ Command = "terraform apply -var=`"github_token=$GitHubToken`" -var=`"github_repository_name=$GitHubRepoName`" -auto-approve"; Message = "Applying Terraform configuration..." }
)
foreach ($command in $commands) {
    Write-Output $command.Command
    Write-Output ""
    $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -Command $($command.Command)" -NoNewWindow -PassThru -Wait
    if ($process.ExitCode -ne 0) {
        Write-Error "Command '$($command.Command)' failed with exit code $($process.ExitCode)."
        exit 1
    }
}

# Capture the output of the terraform apply command
$terraformOutput = & terraform output -json
$GitHubRepositoryUrl = ($terraformOutput | ConvertFrom-Json).github_repository_url.value
$GitHubRepositoryFullName = ($terraformOutput | ConvertFrom-Json).github_repository_full_name.value

# #############################################################################
# Initialize the local repository
# #############################################################################

Write-Host ""
Write-Host ""
Write-Host ""
$originalColor = $Host.UI.RawUI.ForegroundColor
$Host.UI.RawUI.ForegroundColor = "Cyan"
Write-Host "-------------------------------------------------------------------------------"
Write-Host "Initializing the local repository..."
Write-Host "-------------------------------------------------------------------------------"
$Host.UI.RawUI.ForegroundColor = $originalColor

# Navigate to the $TargetPath\cool-revive folder
Set-Location (Join-Path -Path $TargetPath -ChildPath "cool-revive")
#cd (Join-Path -Path $TargetPath -ChildPath "cool-revive")

# Initialize a new Git repository and switch to the develop branch
git init -b develop

# Navigate to the $TargetPath\infra\GitHub folder
Set-Location (Join-Path -Path $TargetPath -ChildPath "cool-revive\infra\github")
#cd (Join-Path -Path $TargetPath -ChildPath "cool-revive\infra\github")

# Add the Terraform configuration files to the repository
git add variables.tf
git add providers.tf
git add main.tf

# Commit the changes
git commit -m "Initial commit with Terraform configuration for GitHub repository."

# Add the remote repository and push the changes
git remote add origin $GitHubRepositoryUrl
#git push -u origin develop

# Pull the changes from the remote repository, allowing unrelated histories
git pull origin develop --allow-unrelated-histories

# Push the changes again to ensure everything is up to date
git push -u origin develop

# #############################################################################
# Copy the root files to the repository
# #############################################################################

Write-Host ""
Write-Host ""
Write-Host ""
$originalColor = $Host.UI.RawUI.ForegroundColor
$Host.UI.RawUI.ForegroundColor = "Cyan"
Write-Host "-------------------------------------------------------------------------------"
Write-Host "Copying the root files to the repository..."
Write-Host "-------------------------------------------------------------------------------"
$Host.UI.RawUI.ForegroundColor = $originalColor

# Check if the feature branch already exists
$branchExists = git branch -r | Select-String -Pattern "origin/features/initial-setup"

if ($branchExists) {
    git checkout features/initial-setup
} else {
    git checkout -b features/initial-setup
}

# Copy files from the root-files folder to the target path
$rootFilesPath = Join-Path -Path $PSScriptRoot -ChildPath "root-files"
Copy-Item -Path $rootFilesPath\* -Destination (Join-Path -Path $TargetPath -ChildPath "cool-revive") -Recurse -Force

# Navigate to the $TargetPath\cool-revive folder
#cd (Join-Path -Path $TargetPath -ChildPath "cool-revive")
Set-Location (Join-Path -Path $TargetPath -ChildPath "cool-revive")

# Add the copied files to the repository
git add .gitignore -f
git add README.md

# Commit the changes
git commit -m "Add initial setup files"

# Push the feature branch to the remote repository
git push -u origin features/initial-setup

# #############################################################################
# Initialize the Terraform remote state
# #############################################################################

Write-Host ""
Write-Host ""
Write-Host ""
$originalColor = $Host.UI.RawUI.ForegroundColor
$Host.UI.RawUI.ForegroundColor = "Cyan"
Write-Host "-------------------------------------------------------------------------------"
Write-Host "Initializing the Terraform remote state..."
Write-Host "-------------------------------------------------------------------------------"
$Host.UI.RawUI.ForegroundColor = $originalColor

# Copy files from initialize-GitHub folder to the target remote-state folder
$sourcePath = Join-Path -Path $PSScriptRoot -ChildPath "initialize-remote-state"
$destinationPath = Join-Path -Path $TargetPath -ChildPath "cool-revive\infra\remote-state"
Copy-Item -Path $sourcePath\* -Destination $destinationPath -Recurse -Force

# Execute Terraform commands
Set-Location -Path $destinationPath
#cd $destinationPath
$commands = @(
    @{ Command = "terraform init"; Message = "Initializing Terraform..." },
    @{ Command = "terraform validate"; Message = "Validating Terraform configuration..." },
    @{ Command = "terraform apply -var=`"azure_environment=dev`" -var=`"azure_region=$AzureRegion`" -var=`"resource_name_suffix=$RandomNameSuffix`" -auto-approve"; Message = "Applying Terraform configuration..." }
)
foreach ($command in $commands) {
    Write-Output $command.Command
    Write-Output ""
    $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -Command $($command.Command)" -NoNewWindow -PassThru -Wait
    if ($process.ExitCode -ne 0) {
        Write-Error "Command '$($command.Command)' failed with exit code $($process.ExitCode)."
        exit 1
    }
}

# Migrate state to the remote state
$filePath = Join-Path -Path $destinationPath -ChildPath "backend.tf"
$fileContent = @'
terraform {
  backend "azurerm" {
  }
}
'@
Set-Content -Path $filePath -Value $fileContent

# Execute the Terraform init command to migrate the state
$CommandToExecute = "terraform init --backend-config=dev.tfconfig -migrate-state -force-copy"
$process = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -Command $CommandToExecute" -NoNewWindow -PassThru -Wait
if ($process.ExitCode -ne 0) {
    Write-Error "Command '$CommandToExecute' failed with exit code $($process.ExitCode)."
    exit 1
}

# Add the new files to the repository
git add backend.tf
git add main.tf

# Commit the changes
git commit -m "Initializing Terraform remote state"

# Push the feature branch to the remote repository
git push -u origin features/initial-setup

# #############################################################################
# Create the Azure Service Principal
# #############################################################################

Write-Host ""
Write-Host ""
Write-Host ""
$originalColor = $Host.UI.RawUI.ForegroundColor
$Host.UI.RawUI.ForegroundColor = "Cyan"
Write-Host "-------------------------------------------------------------------------------"
Write-Host "Creating the Azure Service Principal..."
Write-Host "-------------------------------------------------------------------------------"
$Host.UI.RawUI.ForegroundColor = $originalColor

# Copy files from create-service-principal folder to the target service-principal folder
$sourcePath = Join-Path -Path $PSScriptRoot -ChildPath "create-service-principal"
$destinationPath = Join-Path -Path $TargetPath -ChildPath "cool-revive\infra\service-principal"
Copy-Item -Path $sourcePath\* -Destination $destinationPath -Recurse -Force

# Copy the dev.tfconfig file from the remote state folder to the GitHub folder
$sourcePath = Join-Path -Path $TargetPath -ChildPath "cool-revive\infra\remote-state"
$destinationPath = Join-Path -Path $TargetPath -ChildPath "cool-revive\infra\service-principal"
Copy-Item -Path $sourcePath\dev.tfconfig -Destination $destinationPath -Recurse -Force

Set-Location -Path $destinationPath
#cd $destinationPath

# Update the key in the dev.tfconfig file
$filePath = Join-Path -Path $destinationPath -ChildPath "dev.tfconfig"
$fileContent = Get-Content -Path $filePath
$fileContent = $fileContent -replace 'key = "iac.tfstate"', 'key = "service-principal.tfstate"'
Set-Content -Path $filePath -Value $fileContent

# Execute Terraform commands
$commands = @(
    @{ Command = "terraform init --backend-config=dev.tfconfig"; Message = "Initializing Terraform..." },
    @{ Command = "terraform validate"; Message = "Validating Terraform configuration..." },
    @{ Command = "terraform apply -var=`"azure_environment=dev`" -var=`"azure_region=$AzureRegion`" -var=`"resource_name_suffix=$RandomNameSuffix`" -var=`"github_token=$GitHubToken`" -var=`"github_repository_full_name=$GitHubRepositoryFullName`" -auto-approve"; Message = "Applying Terraform configuration..." }
)

foreach ($command in $commands) {
    Write-Output $command.command
    Write-Output ""
    $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -Command $($command.Command)" -NoNewWindow -PassThru -Wait
    if ($process.ExitCode -ne 0) {
        Write-Error "Command '$($command.Command)' failed with exit code $($process.ExitCode)."
        exit 1
    }
}

# Add the new files to the repository
git add main.tf

# Commit the changes
git commit -m "Creating the Azure Service Principal"

# Push the feature branch to the remote repository
git push -u origin features/initial-setup

# #############################################################################
# Build the GitHub Actions pipelines
# #############################################################################

Write-Host ""
Write-Host ""
Write-Host ""
$originalColor = $Host.UI.RawUI.ForegroundColor
$Host.UI.RawUI.ForegroundColor = "Cyan"
Write-Host "-------------------------------------------------------------------------------"
Write-Host "Building the GitHub Actions pipelines..."
Write-Host "-------------------------------------------------------------------------------"
$Host.UI.RawUI.ForegroundColor = $originalColor

# Copy files from workflows folder to the target workflows folder
$sourcePath = Join-Path -Path $PSScriptRoot -ChildPath "workflows"
$destinationPath = Join-Path -Path $TargetPath -ChildPath "cool-revive\.github\workflows"
Copy-Item -Path $sourcePath\* -Destination $destinationPath -Recurse -Force

# Add the new files to the repository
Set-Location -Path $destinationPath
git add ci.yml
git add cd.yml

# Commit the changes
git commit -m "Adding the GitHub Actions pipelines"

# Push the feature branch to the remote repository
git push -u origin features/initial-setup

# #############################################################################
# Build the Remanufacturing Azure resources
# #############################################################################

Write-Host ""
Write-Host ""
Write-Host ""
$originalColor = $Host.UI.RawUI.ForegroundColor
$Host.UI.RawUI.ForegroundColor = "Cyan"
Write-Host "-------------------------------------------------------------------------------"
Write-Host "Building the rg-CoolRevive-APIManagement resource group Terraform project..."
Write-Host "-------------------------------------------------------------------------------"
$Host.UI.RawUI.ForegroundColor = $originalColor

# Copy files from solution folder to the target solution folder
$sourcePath = Join-Path -Path $PSScriptRoot -ChildPath "solution-apim"
$destinationPath = Join-Path -Path $TargetPath -ChildPath "cool-revive\infra\solution"
Copy-Item -Path $sourcePath\* -Destination $destinationPath -Recurse -Force

# Copy the dev.tfconfig file from the remote state folder to the GitHub folder
$sourcePath = Join-Path -Path $TargetPath -ChildPath "cool-revive\infra\remote-state"
$destinationPath = Join-Path -Path $TargetPath -ChildPath "cool-revive\infra\solution"
Copy-Item -Path $sourcePath\dev.tfconfig -Destination $destinationPath -Recurse -Force

# Update the key in the dev.tfconfig file
Set-Location -Path $destinationPath
$filePath = Join-Path -Path $destinationPath -ChildPath "dev.tfconfig"
$fileContent = Get-Content -Path $filePath
$fileContent = $fileContent -replace 'key = "remanufacturing.tfstate"', 'key = "apim.tfstate"'
Set-Content -Path $filePath -Value $fileContent

# Build the tfvars file
$filePath = Join-Path -Path $destinationPath -ChildPath "dev.tfvars"
$fileContent = @"
azure_region         = "$AzureRegion"
azure_environment    = "dev"
resource_name_suffix = "$RandomNameSuffix"
apim_publisher_name  = "$APIMPublisherName"
apim_publisher_email = "$APIMPublisherEmail"
apim_sku_name        = "Developer_1"
"@
Set-Content -Path $filePath -Value $fileContent

# Execute Terraform commands
$commands = @(
    @{ Command = "terraform init --backend-config=dev.tfconfig"; Message = "Initializing Terraform..." },
    @{ Command = "terraform validate"; Message = "Validating Terraform configuration..." },
    @{ Command = "terraform apply --var-file=dev.tfvars -auto-approve"; Message = "Applying Terraform configuration..." }
)
foreach ($command in $commands) {
    Write-Output $command.command
    Write-Output ""
    $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -Command $($command.Command)" -NoNewWindow -PassThru -Wait
    if ($process.ExitCode -ne 0) {
        Write-Error "Command '$($command.Command)' failed with exit code $($process.ExitCode)."
        exit 1
    }
}

# Add the new files to the repository
git add dev.tfvars
git add main-apim.tf
git add main-core.tf
git add main-inventorymanager.tf
git add main-ordernextcore.tf
git add modules.tf
git add providers.tf
git add tags.tf
git add variables.tf

# Commit the changes
git commit -m "Adding the Solution Terraform project"

# Push the feature branch to the remote repository
git push -u origin features/initial-setup

# #############################################################################
# Create the Visual Studio Solution
# #############################################################################

Write-Host ""
Write-Host ""
Write-Host ""
$originalColor = $Host.UI.RawUI.ForegroundColor
$Host.UI.RawUI.ForegroundColor = "Cyan"
Write-Host "-------------------------------------------------------------------------------"
Write-Host "Building the rg-CoolRevive_Remanufacturing_OrderNextCore resource group Terraform project..."
Write-Host "-------------------------------------------------------------------------------"
$Host.UI.RawUI.ForegroundColor = $originalColor

# Copy files from src folder to the target src folder
$sourcePath = Join-Path -Path $PSScriptRoot -ChildPath "src"
$destinationPath = Join-Path -Path $TargetPath -ChildPath "cool-revive\src"
Copy-Item -Path $sourcePath\* -Destination $destinationPath -Recurse -Force

# Add the new files to the repository
Set-Location -Path $destinationPath
git add Remanufacturing.sln

# Commit the changes
git commit -m "Adding the Remanufacturing solution"

# Push the feature branch to the remote repository
git push -u origin features/initial-setup







# #############################################################################
# Wrap up
# #############################################################################

# Return to the original directory
Set-Location -Path $originalPath

Write-Output "Environment initialization completed successfully."
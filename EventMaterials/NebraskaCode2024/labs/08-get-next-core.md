[Design and Develop a Serverless Event-Driven Microservice-Based Solution](https://github.com/TaleLearnCode/EDAMicroserviceWorkshop) \ [Nebraska.Code 2024](README.md)  \ [Labs](README.md) \

# Lab 8: Get Next Core

## Objective

The first segment of the **Order Next Core** process is to retrieve the details of the next core scheduled to be remanufactured. This is handled by the **Get Next Core** procedure.  Cool Revive has several different ways how the core information is retrieved, but they wanted to abstract that away from the **Order Next Core** process. So the design is to implement a message-based architecture.  The steps within this procedure are:

1. An HTTP POST is sent an endpoint to get the next core.
2. That endpoint will send a message to the Service Bus requesting information on the next core in the production schedule.
3. The appropriate message handler will pick up that message and will do what is needed to retrieve the core information and then send a message to the Service Bus to order the next core.
   - For our scenario, the message handler will make an HTTP GET request to the Production Schedule Facade service via API Management.

Let's build out the Get Next Core procedure.

## Prerequisites

- Completion of [Lab 7](07-production-schedule.md) .
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
git branch features/08-get-next-core
```

5. Checkout the feature branch for the lab:

```sh
git checkout features/08-get-next-core
```

### Step 2: Configure the Service Bus namespace

1. In the `infra\modules.tf` file, add the following configuration:

```HCL
module "service_bus_namespace" {
  source        = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "service-bus-namespace"
}
```

2. In the `infra\remanufacturing.tf` file, add the following configuration:

```HCL
# -----------------------------------------------------------------------------
# Service Bus
# -----------------------------------------------------------------------------

resource "azurerm_servicebus_namespace" "remanufacturing" {
  name                = lower("${module.service_bus_namespace.name.abbreviation}-Remanufacturing${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}")
  location            = data.azurerm_resource_group.remanufacturing.location
  resource_group_name = data.azurerm_resource_group.remanufacturing.name
  sku                 = "Standard"
  tags                = local.remanufacturing_tags
}
```

### Step 3: Configure the Get Next Core Topic and Subscription

1. Add the following configuration to the `infra\modules.tf` file:

```HCL
module "service_bus_topic" {
  source = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "service-bus-topic"
}

module "service_bus_topic_subscription" {
  source = "git::https://github.com/TaleLearnCode/azure-resource-types.git"
  resource_type = "service-bus-topic-subscription"
}
```



1. Create the `infra\get-next-core.tf` file and add the following configuration to the file:

```HCL
# ------------------------------------------------------------------------------
# Get Next Core Service Bus Topic
# ------------------------------------------------------------------------------

resource "azurerm_servicebus_topic" "get_next_core" {
  name                      = "${module.service_bus_topic.name.abbreviation}-GetNextCore${var.resource_name_suffix}-${var.azure_environment}-${module.azure_regions.region.region_short}"
  namespace_id              = azurerm_servicebus_namespace.remanufacturing.id
  support_ordering          = true
  depends_on = [ 
    azurerm_servicebus_namespace.remanufacturing
   ]
}

resource "azurerm_app_configuration_key" "get_next_core_topic_name" {
  configuration_store_id = azurerm_app_configuration.remanufacturing.id
  key                    = "ServiceBus:Topic:GetNextCore"
  label                  = var.azure_environment
  value                  = azurerm_servicebus_topic.get_next_core.name
  lifecycle {
    ignore_changes = [configuration_store_id]
  }
}

resource "azurerm_servicebus_topic_authorization_rule" "get_next_core_sender" {
  name     = "GetNextCoreSender"
  topic_id = azurerm_servicebus_topic.get_next_core.id
  listen   = false
  send     = true
  manage   = false
}

module "get_next_core_sender_connection_string" {
  source                 = "./modules/app-config-secret"
  app_config_label       = var.azure_environment
  app_config_key         = "ServiceBus:Topic:GetNextCore:SenderConnectionString"
  configuration_store_id = azurerm_app_configuration.remanufacturing.id
  key_vault_id           = azurerm_key_vault.remanufacturing.id
  secret_name            = "ServiceBus-Topic-GetNextCore-SenderConnectionString"
  secret_value            = azurerm_servicebus_topic_authorization_rule.get_next_core_sender.primary_connection_string
}

resource "azurerm_servicebus_topic_authorization_rule" "get_next_core_listener" {
  name     = "GetNextCoreListener"
  topic_id = azurerm_servicebus_topic.get_next_core.id
  listen   = true
  send     = false
  manage   = false
}

module "get_next_core_listener_connection_string" {
  source                 = "./modules/app-config-secret"
  app_config_label       = var.azure_environment
  app_config_key         = "ServiceBus:Topic:GetNextCore:ListenerConnectionString"
  configuration_store_id = azurerm_app_configuration.remanufacturing.id
  key_vault_id           = azurerm_key_vault.remanufacturing.id
  secret_name            = "ServiceBus-Topic-GetNextCore-ListenerConnectionString"
  secret_value            = azurerm_servicebus_topic_authorization_rule.get_next_core_sender.primary_connection_string
}

resource "azurerm_servicebus_subscription" "get_next_core" {
  name               = "${module.service_bus_topic_subscription.name.abbreviation}-GetNextCore-${var.azure_environment}-${module.azure_regions.region.region_short}"
  topic_id           = azurerm_servicebus_topic.get_next_core.id
  max_delivery_count = 10
}
```

### Step 4: Configure Get Next Core Azure Function

1. Add the following configuration to the `infra\get-next-core.tf` file in order to manage the **Get Next Core** Azure Function.

```HCL
# ------------------------------------------------------------------------------
# Get Next Core Function App
# ------------------------------------------------------------------------------

module "get_next_core_function_app" {
  source = "./modules/function-consumption"
  app_configuration_id           = azurerm_app_configuration.remanufacturing.id
  app_insights_connection_string = azurerm_application_insights.remanufacturing.connection_string
  azure_environment              = var.azure_environment
  azure_region                   = var.azure_region
  function_app_name              = "GetNextCore"
  key_vault_id                   = azurerm_key_vault.remanufacturing.id
  resource_group_name            = azurerm_resource_group.remanufacturing.name
  resource_name_suffix           = var.resource_name_suffix
  storage_account_name           = "psf"
  tags                           = local.remanufacturing_tags
  #app_settings = {
  #  "GetNextCoreTopicName" = "@Microsoft.AppConfiguration(Endpoint=${azurerm_app_configuration.remanufacturing.endpoint}; Key=${azurerm_app_configuration_key.get_next_core_topic_name.key}; Label=${azurerm_app_configuration_key.get_next_core_topic_name.label})",
  #}
  app_settings = {
    "GetNextCoreTopicName"       = azurerm_servicebus_topic.get_next_core.name
  }
  depends_on = [ azurerm_resource_group.remanufacturing ]
}
```



### Step 4: Commit and push the Terraform project to your central Git repository

1. Click on the `Source Control` tab within Visual Studio code.
2. Add an appropriate commit message:

```
Adding initial infrastructure for Get Next Core.
```

3. Click the **Commit** button (this will perform a `git commit` command).
4. Click the **Publish Branch** button (this will perform a `git push` command).

### Step 5: Create a pull request and merge it into develop

#### Using GitHub

1. Navigate to your GitHub repository.
2. Click the **Pull requests** tab.
3. Click the **New pull request** button.
4. Change the **compare** to `features/08-get-next-core`.
5. Click the **Create pull request** button.
6. Click the **Create pull request** button.
7. Once all of the checks have passed, click the **Merge pull request** button.
8. Click the **Confirm merge** button.
9. Open the **Actions** tab in a separate browser tab and validate that the `Terraform (CD)` pipeline is running.

Validate that the **Terraform (cd)** pipeline is executed successfully.

### Step 6: Initialize the Messaging Class Library

1. With the Remanufacturing solution open in Visual Studio, right-click the `Core` solution folder and select **Add** > **New Project**.
2. Search for and select **Class Library** and click the **Next button**.
3. Name the new project `Messaging` and append `Core` to the location path (e.g., `C:\Repos\cool-revive-remanufacturing\src\Core`).
4. Select `.NET 8.0 (Long Term Support)` for the **Framework** and click the **Create** button.
5. Delete the `Class1.cs` file.
6. Double-click the `Messaging` project to open the `csproj` file.
7. Add the latest version of the following NuGet packages to the project:
   - Azure.Identity
   - Azure.Messaging.ServiceBus
8. Add `<RootNamespace>Remanufacturing</RootNamespace>` to the `<PropertyGroup>`. Your file should look similar to:

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <RootNamespace>Remanufacturing</RootNamespace>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Azure.Identity" Version="1.12.0" />
    <PackageReference Include="Azure.Messaging.ServiceBus" Version="7.17.5" />
  </ItemGroup>

</Project>

```

9. Add a folder named `Messages` to the project.
10. Add an interface named `ISericeBusMessage.cs` to the `Messages` folder and replace the default content with:

```c#
namespace Remanufacturing.Messages;

/// <summary>
/// Interface for Cool Revive Remanufacturing messages.
/// </summary>
public interface IServiceBusMessage
{

	/// <summary>
	/// Gets or sets the tracking identifier for the message.
	/// </summary>
	string MessageId { get; set; }

	/// <summary>
	/// Gets or sets the type of the message.
	/// </summary>
	string MessageType { get; set; }

}
```

11. Add a class named `MessageTypes.cs` to the `Messages` folder and replace the default content with:

```c#
namespace Remanufacturing.Messages;

public static class MessageTypes
{
	public const string OrderNextCore = "OrderNextCore";
}
```

12. Add a class named `OrderNextCoreMessage.cs` to the `Messages` folder and replace the default content with:

```c#
namespace Remanufacturing.Messages;

public class OrderNextCoreMessage : IServiceBusMessage
{
	public string MessageId { get; set; } = Guid.NewGuid().ToString();
	public string MessageType { get; set; } = MessageTypes.OrderNextCore;
	public string PodId { get; set; } = null!;
	public string? CoreId { get; set; }
	public string? FinishedProductId { get; set; }
	public DateTime RequestDateTime { get; set; }
}
```

13. Add a folder named `Exceptions` to the project.
14. Add a class named `MessageTooLargeForBatchException` to the `Exceptions` folder and replace the default content with:

```c#
namespace Remanufacturing.Exceptions;

public class MessageTooLargeForBatchException : Exception
{
	public MessageTooLargeForBatchException() : base("One of the messages is too large to fit in the batch.") { }
	public MessageTooLargeForBatchException(int messageIndex) : base($"The message {messageIndex} is too large to fit in the batch.") { }
	public MessageTooLargeForBatchException(string message) : base(message) { }
	public MessageTooLargeForBatchException(string message, Exception innerException) : base(message, innerException) { }
}
```



15. Add a folder named `Services` to the project.
16. Add a class named `ServiceBusServices.cs` to the `Services` folder and replace the default content with:

``` c#
using Azure.Messaging.ServiceBus;
using Remanufacturing.Exceptions;
using System.Text;
using System.Text.Json;

namespace Remanufacturing.Services;

/// <summary>
/// Helper methods for sending messages to a Service Bus topic.
/// </summary>
public class ServiceBusServices
{

	/// <summary>
	/// Sends a single message to a Service Bus topic.
	/// </summary>
	/// <typeparam name="T">The type of the message value.</typeparam>
	/// <param name="serviceBusClient">The Service Bus client.</param>
	/// <param name="topicName">The name of the topic.</param>
	/// <param name="value">The value to be serialized into a message to be sent to the Service Bus topic.</param>
	public static async Task SendMessageAsync<T>(ServiceBusClient serviceBusClient, string topicName, T value)
	{
		ServiceBusSender sender = serviceBusClient.CreateSender(topicName);
		ServiceBusMessage serviceBusMessage = new(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(value)));
		await sender.SendMessageAsync(serviceBusMessage);
	}

	/// <summary>
	/// Sends a batch of messages to a Service Bus topic.
	/// </summary>
	/// <typeparam name="T">The type of the message values.</typeparam>
	/// <param name="serviceBusClient">The Service Bus client.</param>
	/// <param name="topicName">The name of the topic.</param>
	/// <param name="values">The Collection of message values to be serialized into message to be sent to the Service Bus topic.</param>
	/// <exception cref="MessageTooLargeForBatchException">Thrown when a message is too large to fit in the batch.</exception>
	public static async Task SendMessageBatchAsync<T>(ServiceBusClient serviceBusClient, string topicName, IEnumerable<T> values)
	{
		await using ServiceBusSender sender = serviceBusClient.CreateSender(topicName);
		using ServiceBusMessageBatch messageBatch = await sender.CreateMessageBatchAsync();
		for (int i = 0; i < values.Count(); i++)
		{
			string message = JsonSerializer.Serialize<T>(values.ElementAt(i));
			if (!messageBatch.TryAddMessage(new ServiceBusMessage(message)))
				throw new MessageTooLargeForBatchException(i);
		}
		await sender.SendMessagesAsync(messageBatch);
	}

}
```

### Step 7: Develop the Get Next Core Functionality

1. Open the Remanufacturing solution in Visual Studio and add an `Get Next Core` solution folder.
2. Right-click the `Get Next Core` solution folder and select **Add** > **New Project**.
3. Search for and select **Class Library** and click the **Next** button.
4. Name the new project `GetNextCore.Services` and append `GetNextCore` to the location path (for example `C:\Repos\cool-revive-remanufacturing\src\GetNextCore`). Click the **Next** button.
5. Select `.NET 8.0 (Long Term Support)` for the **Framework** and click the **Create** button.
6. Delete the `Class1.cs` file.
7. Add a project reference to the `Messaging` and `Responses` projects.
8. Double-click the `GetNextCore.Services` project to open the `csproj` file and add `<RootNamespace>Remanufacturing.OrderNextCore</RootNamespace>` to the `<PropertyGroup>`. Your file should look similar to:

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <RootNamespace>Remanufacturing.OrderNextCore</RootNamespace>
  </PropertyGroup>

  <ItemGroup>
    <ProjectReference Include="..\..\Core\Messaging\Messaging.csproj" />
    <ProjectReference Include="..\..\Core\Responses\Responses.csproj" />
  </ItemGroup>

</Project>
```

9. Add a folder named `Services` to the project.
10. Add a class named `GetNextCoreServicesOptions.cs` to the `Services` folder and replace the default content with:

``` c#
using Azure.Messaging.ServiceBus;

namespace Remanufacturing.OrderNextCore.Services;

public class GetNextCoreServicesOptions
{
	public ServiceBusClient ServiceBusClient { get; set; } = null!;
	public string GetNextCoreTopicName { get; set; } = null!;
}
```

11. Add a class named `GetNextCoreServices.cs` to the `Services` folder and replace the default content with:

```c#
using Remanufacturing.Messages;
using Remanufacturing.Responses;
using Remanufacturing.Services;
using System.Net;

namespace Remanufacturing.OrderNextCore.Services;

public class GetNextCoreServices(OrderNextCoreServicesOptions options)
{

	private readonly GetNextCoreServicesOptions _servicesOptions = options;

	public async Task<IResponse> RequestNextCoreInformationAsync(OrderNextCoreMessage orderNextCoreMessage, string instance)
	{
		try
		{
			ArgumentException.ThrowIfNullOrEmpty(orderNextCoreMessage.PodId, nameof(orderNextCoreMessage.PodId));
			if (orderNextCoreMessage.RequestDateTime == default)
				orderNextCoreMessage.RequestDateTime = DateTime.UtcNow;
			await ServiceBusServices.SendMessageAsync(_servicesOptions.ServiceBusClient, _servicesOptions.GetNextCoreTopicName, orderNextCoreMessage);
			return new StandardResponse()
			{
				Type = "https://httpstatuses.com/201", // HACK: In a real-world scenario, you would want to provide a more-specific URI reference that identifies the response type.
				Title = "Request for next core id sent.",
				Status = HttpStatusCode.Created,
				Detail = "The request for the next core id has been sent to the Production Schedule.",
				Instance = instance,
				Extensions = new Dictionary<string, object>()
				{
					{ "PodId", orderNextCoreMessage.PodId },
				}
			};
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
				Title = "An error occurred while sending the message to the Service Bus",
				Status = HttpStatusCode.InternalServerError,
				Detail = ex.Message, // HACK: In a real-world scenario, you would not want to expose the exception message to the client.
				Instance = instance
			};
		}
	}

}
```

### Step 8: Develop the Get Next Core Azure Function

1. Right-click on the `Get Next Core` solution folder and select **Add** > **New Project**.
2. Search for and select **Azure Functions** and click the **Next** button.
3. Name the project `GetNextCore.Functions` and place in the `GetNextCore` folder.
4. Select the `.NET 8.0 Isolated (Long Term Support)` **Function worker** and the `Http trigger` **Function** and click the **Create** button.
5. Delete the `Function1.cs` file.
6. Add a project reference to the `GetNextCore.Services` project.
7. Double-click the `OrderNextCore.Services` project to open the `csproj` file and add `<RootNamespace>Remanufacturing.OrderNextCore</RootNamespace>` to the `<PropertyGroup>`. Your file should look similar to:

``` xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <AzureFunctionsVersion>v4</AzureFunctionsVersion>
    <OutputType>Exe</OutputType>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <RootNamespace>Remanufacturing.OrderNextCore</RootNamespace>
  </PropertyGroup>
  <ItemGroup>
    <FrameworkReference Include="Microsoft.AspNetCore.App" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker" Version="1.22.0" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.Http" Version="3.2.0" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.Http.AspNetCore" Version="1.3.2" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker.Sdk" Version="1.17.4" />
    <PackageReference Include="Microsoft.ApplicationInsights.WorkerService" Version="2.22.0" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker.ApplicationInsights" Version="1.2.0" />
  </ItemGroup>
  <ItemGroup>
    <ProjectReference Include="..\GetNextCore.Services\GetNextCore.Services.csproj" />
  </ItemGroup>
  <ItemGroup>
    <None Update="host.json">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
    </None>
    <None Update="local.settings.json">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
      <CopyToPublishDirectory>Never</CopyToPublishDirectory>
    </None>
  </ItemGroup>
  <ItemGroup>
    <Using Include="System.Threading.ExecutionContext" Alias="ExecutionContext" />
  </ItemGroup>
</Project>
```

8. Open the `Program.cs` file and update the contents with the following:

```c#
using Azure.Messaging.ServiceBus;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Remanufacturing.OrderNextCore.Services;

GetNextCoreServicesOptions getNextCoreServicesOptions = new()
{
	ServiceBusClient = new ServiceBusClient(Environment.GetEnvironmentVariable("ServiceBusConnectionString")!),
	GetNextCoreTopicName = Environment.GetEnvironmentVariable("GetNextCoreTopicName")!,
};

IHost host = new HostBuilder()
	.ConfigureFunctionsWebApplication()
	.ConfigureServices(services =>
	{
		services.AddApplicationInsightsTelemetryWorkerService();
		services.ConfigureFunctionsApplicationInsights();
		services.AddHttpClient();
		services.AddSingleton(new GetNextCoreServices(getNextCoreServicesOptions));
	})
	.Build();

host.Run();
```

9. Add a folder named `Functions` to the project.
10. Add an Http triggered Azure Function named `GetNexttCore.cs` to the `Services` folder and replace the default content with:

```c#
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Remanufacturing.Messages;
using Remanufacturing.OrderNextCore.Services;
using Remanufacturing.Responses;
using System.Net;
using System.Text.Json;

namespace Remanufacturing.OrderNextCore.Functions;

public class GetNextCore(ILogger<GetNextCore> logger, GetNextCoreServices getNextCoreServices)
{

	private readonly ILogger<GetNextCore> _logger = logger;
	private readonly GetNextCoreServices _getNextCoreServices = getNextCoreServices;

	[Function("GetNextCore")]
	public async Task<IActionResult> RunAsync([HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequest request)
	{
		string requestBody = await new StreamReader(request.Body).ReadToEndAsync();
		OrderNextCoreMessage? nextCoreRequestMessage = JsonSerializer.Deserialize<OrderNextCoreMessage>(requestBody);
		if (nextCoreRequestMessage is not null)
		{
			_logger.LogInformation("Get next core for Pod '{podId}'", nextCoreRequestMessage.PodId);
			IResponse response = await _getNextCoreServices.RequestNextCoreInformationAsync(nextCoreRequestMessage, request.HttpContext.TraceIdentifier);
			return new ObjectResult(response) { StatusCode = (int)HttpStatusCode.OK };
		}
		else
		{
			_logger.LogWarning("Invalid request body.");
			return new BadRequestObjectResult("Invalid request body.");
		}
	}

}
```

### Step 9: Test the Azure Function locally

1. From the [Azure Portal](https://portal.azure.com), search for `sbns-remanufacturing` and select the appropriate Service Bus Namespace.
2. Click on the **Topics** tab.
3. Click on the `sbt-getnextcore...` topic.
4. Click on **Shared access policies**.
5. Click on `GetNextCoreSender` and copy the **Primary Connection String**.
6. In the `local.settings.json` file of the `GetNextCore` project, add the following key/value pairs:
   - ServiceBusConnectionString - The primary key you just copied.
   - GetNextCoreTopicName - The name of the GetNextCore topic from the portal.
7. Right-click the `GetNextCore` project and select **Set as Startup Project**.
8. Press **F5** to start the Azure Function app locally.
9. Copy the **GetNextCore** endpoint.
10. Open Postman and enter the **GetNextCore** in the **Enter URL or paste text** field.
11. Change the HTTP method to **POST**.
12. Go to the **Body** tab.
13. Select **raw**.
14. Paste the following into the request body field:

```json
{
    "MessageId": "message-123",
    "MessageType": "GetNextCore",
    "PodId": "Pod123"
}
```

15. Click the **Send** button. You should receive a **201 Created** response with a response body similar to:

```json
{
    "type": "https://httpstatuses.com/201",
    "title": "Request for next core id sent.",
    "status": 201,
    "detail": "The request for the next core id has been sent to the Production Schedule.",
    "instance": "0HN547NP89O2R:00000001",
    "extensions": {
        "PodId": "Pod123"
    }
}
```

16. Back in the [Azure Portal](https://portal.azure.com), click the **Service Bus Explorer** menu item (assuming you are still in the sbt-getnextcore topic from before).
17. Select the `sbts-GetNextCore` subscription and then click the **Peak from start** button. You should see the message that was just sent to the Service Bus topic.

### Step 10: Create a solution for Get Next Core

We will create a separate solution file for them to use to ease the build process in the upcoming YAML pipelines.

1. In Visual Studio, close the solution.
2. Click the Create a new project button from the Visual Studio Start Window.
3. Search for and click the **Blank Solution** option; click the **Next** button.
4. Enter `GetNextCore` in the name and select the `GetNextCore` folder with your local repository.
5. Close the solution.
6. Click the **Open a local folder** button from the Visual Studio Start Window.
7. Select your repository folder.
8. Drag the `GetNextCore.sln` file from the `..\src\GetNextCore\GetNextCore` folder to the `...\src\GetNextCore` folder.
9. Delete the `...\src\GetNextCore\GetNextCore` folder.
10. Double-click the `GetNextCore.sln` file.
11. Add the `..\src\Core\Responses\Responses.csproj` project to the solution.
12. Add the `..\src\GetNextCore\GetNextCore.Services\GetNextCore.Services.csproj` project to the solution.
13. Add the `..\src\GetNextCore\GetNextCore.Functions\GetNextCore.Functions.csproj` project to the solution.
14. Build the solution and correct any problems.

### Step 11: Update the CI Pipeline

1. Open the `.github\workflows\ci.yml` pipeline.
2. Add `get-next-core: ${{ steps.filter.outputs.get-next-core }}` to the `path-filter` job's `outputs`.
3. Add the following filter to the `path-filter` step:

```yaml
            get-next-core:
              - 'src/GetNextCore/**'
```

4. Add the following `get-next-order` job to the pipeline:

```yaml
  get-next-core:
    name: 'Get Next Core CI'
    needs: paths-filter
    runs-on: ubuntu-latest
    if: needs.paths-filter.outputs.get-core-order == 'true'
    steps:
    - name: Checkout code
      uses: actions/checkout@v2

    - name: Set up .NET Core
      uses: actions/setup-dotnet@v1
      with:
        dotnet-version: '8.x'

    - name: Restore dependencies
      run: dotnet restore
      working-directory: ./src/GetNextCore

    - name: Build project
      run: dotnet build GetNextCore.sln --configuration Release
      working-directory: ./src/GetNextCore
      
    - name: Publish artifacts
      run: dotnet publish --configuration Release --output ./publish
      working-directory: ./src/GetNextCore

    - name: Upload artifacts
      uses: actions/upload-artifact@v2
      with:
        name: csharp-artifacts
        path: ./publish
```

### Step 12: Update the CD Pipeline

1. Open the `.github\workflows\cd.yml` pipeline.
2. Add `get-next-core: ${{ steps.filter.outputs.get-next-core}}` to the `path-filter` job's `outputs`.
3. Add the following filter to the `path-filter` step:

```yaml
            get-next-core:
              - 'src/GetNextOrder/**'
```

4. Add the following `get-next-core` job to the pipeline:

```yaml
  get-next-order:
    name: 'Get Next Order CI'
    needs: paths-filter
    env:
      AZURE_FUNCTIONAPP_NAME: '<<FUNCTION_APP_NAME>>'
      AZURE_FUNCTIONAPP_PACKAGE_PATH: 'src/GetNextCore/GetNextCore.Functions'
      DOTNET_VERSION: '8.0.x'
    runs-on: ubuntu-latest
    if: needs.paths-filter.outputs.get-next-core == 'true'
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
          publish-profile: ${{ secrets.GET_NEXT_ORDER_FACADE_PUBLISH_PROFILE }}
```

Replace `<<FUNCTION_APP_NAME>>` with the name of the `func-GetNextCore` Azure Function App.

### Step 13: Commit and push the Terraform project to your central Git repository

1. Click on the `Source Control` tab within Visual Studio code.
2. Add an appropriate commit message:

```
Adding the Get Next Core Azure Function.
```

3. Click the **Commit** button (this will perform a `git commit` command).
4. Click the **Publish Branch** button (this will perform a `git push` command).

### Step 14: Create a pull request and merge it into develop

#### Using GitHub

1. Navigate to your GitHub repository.
2. Click the **Pull requests** tab.
3. Click the **New pull request** button.
4. Change the **compare** to `features/08-get-next-core`.
5. Click the **Create pull request** button.
6. Click the **Create pull request** button.
7. Once all of the checks have passed, click the **Merge pull request** button.
8. Click the **Confirm merge** button.
9. Open the **Actions** tab in a separate browser tab and validate that the `Terraform (CD)` pipeline is running.

Validate that the **Terraform (cd)** pipeline is executed successfully.

### Step 15: Develop the Get Next Core Handler Functionality

1. Open the Remanufacturing solution in Visual Studio and add a `Get Next Core Handler` solution folder.
2. Right-click the `Get Next Core Handler` solution folder and select **Add** > **New Project**.
3. Search for and select **Class Library** and click the **Next** button.
4. Name the new project `GetNextCoreHandler.Services` and append `GetNextCoreHandler` to the location path (for example `C:\Repos\cool-revive-remanufacturing\src\GetNextCoreHandler`). Click the **Next** button.
5. Select `.NET 8.0 (Long Term Support)` for the **Framework** and click the **Create** button.
6. Delete the `Class1.cs` file.
7. Add a project reference to the `Messaging` and `Responses` projects.
8. Double-click the `GetNextCore.Services` project to open the `csproj` file and add `<RootNamespace>Remanufacturing.OrderNextCore</RootNamespace>` to the `<PropertyGroup>`. Your file should look similar to:

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <RootNamespace>Remanufacturing.OrderNextCore</RootNamespace>
  </PropertyGroup>

  <ItemGroup>
    <ProjectReference Include="..\..\Core\Messaging\Messaging.csproj" />
    <ProjectReference Include="..\..\Core\Responses\Responses.csproj" />
  </ItemGroup>

</Project>
```

9. Add a folder named `Services` to the project.
10. Add a class named `GetNextCoreHandlerOptions.cs` to the `Services` folder and replace the default content with:

```
using Azure.Messaging.ServiceBus;

namespace Remanufacturing.OrderNextCore.Services;

public class GetNextCoreServicesOptions
{
	public ServiceBusClient ServiceBusClient { get; set; } = null!;
	public string OrderNextCoreTopicName { get; set; } = null!;
	public Dictionary<string, Uri> GetNextCoreUris { get; set; } = [];
}
```

11. Add a class named `GetNextCoreHandlerServices.cs` to the `Services` folder and replace the default content with:

```c#
using Remanufacturing.Messages;
using Remanufacturing.Responses;
using Remanufacturing.Services;
using System.Net;
using System.Text.Json;

namespace Remanufacturing.OrderNextCore.Services;

public class GetNextCoreHandlerServices(GetNextCoreServicesOptions options)
{

	private readonly GetNextCoreServicesOptions _servicesOptions = options;

	public async Task<IResponse> OrderNextCoreAsync(OrderNextCoreMessage nextCoreRequestMessage, string instance)
	{
		try
		{
			ArgumentException.ThrowIfNullOrEmpty(nextCoreRequestMessage.PodId, nameof(nextCoreRequestMessage.PodId));
			ArgumentException.ThrowIfNullOrEmpty(nextCoreRequestMessage.CoreId, nameof(nextCoreRequestMessage.CoreId));
			if (nextCoreRequestMessage.RequestDateTime == default)
				nextCoreRequestMessage.RequestDateTime = DateTime.UtcNow;
			await ServiceBusServices.SendMessageAsync(_servicesOptions.ServiceBusClient, _servicesOptions.OrderNextCoreTopicName, nextCoreRequestMessage);
			return new StandardResponse()
			{
				Type = "https://httpstatuses.com/201", // HACK: In a real-world scenario, you would want to provide a more-specific URI reference that identifies the response type.
				Title = "Request for next core sent.",
				Status = HttpStatusCode.Created,
				Detail = "The request for the next core has been sent to the warehouse.",
				Instance = instance,
				Extensions = new Dictionary<string, object>()
				{
					{ "PodId", nextCoreRequestMessage.PodId },
					{ "CoreId", nextCoreRequestMessage.CoreId }
				}
			};
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
				Title = "An error occurred while sending the message to the Service Bus",
				Status = HttpStatusCode.InternalServerError,
				Detail = ex.Message, // HACK: In a real-world scenario, you would not want to expose the exception message to the client.
				Instance = instance
			};
		}
	}

	public async Task<IResponse> GetNextCoreAsync(HttpClient httpClient, OrderNextCoreMessage orderNextCoreMessage)
	{
		try
		{
			if (!_servicesOptions.GetNextCoreUris.TryGetValue(orderNextCoreMessage.PodId, out Uri? getNextCoreUrl))
				throw new ArgumentOutOfRangeException(nameof(orderNextCoreMessage.PodId), $"The pod ID '{orderNextCoreMessage.PodId}' is not valid.");
			HttpResponseMessage httpResponse = await httpClient.GetAsync(getNextCoreUrl);
			httpResponse.EnsureSuccessStatusCode();
			string responseBody = await httpResponse.Content.ReadAsStringAsync();
			IResponse? response = JsonSerializer.Deserialize<IResponse>(responseBody);
			return response ?? throw new InvalidOperationException("The response from the GetNextCore service was not in the expected format.");
		}
		catch (ArgumentException ex)
		{
			return new ProblemDetails(ex);
		}
		catch (Exception ex)
		{
			return new ProblemDetails()
			{
				Type = "https://httpstatuses.com/500", // HACK: In a real-world scenario, you would want to provide a more-specific URI reference that identifies the response type.
				Title = "An error occurred while sending the message to the Service Bus",
				Status = HttpStatusCode.InternalServerError,
				Detail = ex.Message // HACK: In a real-world scenario, you would not want to expose the exception message to the client.
			};
		}
	}

}
```

### Step 16: Develop the Get Next Core Handler Azure Function

1. Right-click on the `Get Next Core Handler` solution folder and select **Add** > **New Project**.
2. Search for and select **Azure Functions** and click the **Next** button.
3. Name the project `GetNextCoreHandler.Functions` and place in the `GetNextCoreHandler` folder.
4. Specify the following values on the **Additional information** dialog:

| Field                          | Value                                  |
| ------------------------------ | -------------------------------------- |
| Functions Worker               | .NET 8.0 Isolated (Long Term Support)  |
| Function                       | Service Bus Topic trigger              |
| Connection string setting name | ServiceBusConnectionString             |
| Subscription name              | %GetNextCoreForPod123SubscriptionName% |
| Topic name                     | %GetNextCoreTopicName%                 |

5. Click the **Create** button.
6. Add a project reference to the `GetNextCoreHandler.Services` project.
7. Double-click the `OrderNextCoreHandler.Services` project to open the `csproj` file and add `<RootNamespace>Remanufacturing.OrderNextCore</RootNamespace>` to the `<PropertyGroup>`. Your file should look similar to:

``` xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <AzureFunctionsVersion>v4</AzureFunctionsVersion>
    <OutputType>Exe</OutputType>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <RootNamespace>Remanufacturing.OrderNextCore</RootNamespace>
  </PropertyGroup>
  <ItemGroup>
    <FrameworkReference Include="Microsoft.AspNetCore.App" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker" Version="1.22.0" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.Http" Version="3.2.0" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.Http.AspNetCore" Version="1.3.2" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker.Extensions.ServiceBus" Version="5.20.0" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker.Sdk" Version="1.17.4" />
    <PackageReference Include="Microsoft.ApplicationInsights.WorkerService" Version="2.22.0" />
    <PackageReference Include="Microsoft.Azure.Functions.Worker.ApplicationInsights" Version="1.2.0" />
  </ItemGroup>
  <ItemGroup>
    <ProjectReference Include="..\GetNextCoreHandler.Services\GetNextCoreHandler.Services.csproj" />
  </ItemGroup>
  <ItemGroup>
    <None Update="host.json">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
    </None>
    <None Update="local.settings.json">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
      <CopyToPublishDirectory>Never</CopyToPublishDirectory>
    </None>
  </ItemGroup>
  <ItemGroup>
    <Using Include="System.Threading.ExecutionContext" Alias="ExecutionContext" />
  </ItemGroup>
</Project>
```

8. Open the `Program.cs` file and update the contents with the following:

```c#
using Azure.Messaging.ServiceBus;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Remanufacturing.OrderNextCore.Services;

GetNextCoreServicesOptions getNextCoreServicesOptions = new()
{
	ServiceBusClient = new ServiceBusClient(Environment.GetEnvironmentVariable("ServiceBusConnectionString")!),
	OrderNextCoreTopicName = Environment.GetEnvironmentVariable("OrderNextCoreTopicName")!,
	GetNextCoreUris = new Dictionary<string, Uri>()
	{
		// HACK: In a real-world scenario, you would want to set the URIs different so as to not hard-code them.
		{ "Pod123", new Uri(Environment.GetEnvironmentVariable("GetNextCoreUri123")!) }
	}
};

IHost host = new HostBuilder()
	.ConfigureFunctionsWebApplication()
	.ConfigureServices(services =>
	{
		services.AddApplicationInsightsTelemetryWorkerService();
		services.ConfigureFunctionsApplicationInsights();
		services.AddSingleton(new GetNextCoreHandlerServices(getNextCoreServicesOptions));
	})
	.Build();

host.Run();
```

9. Add a folder to the project named `Functions`.
10. Drag Function1.cs to the `Functions` folder and rename the class to GetNextCoreHandler.
11. Replace the default text in `GetNextCoreHandler.cs` with:

``` c#
using Azure.Messaging.ServiceBus;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Remanufacturing.Messages;
using Remanufacturing.OrderNextCore.Services;
using Remanufacturing.Responses;
using System.Text.Json;

namespace Remanufacturing.OrderNextCore.Functions;

public class GetNextCoreHandler(
	ILogger<GetNextCoreHandler> logger,
	IHttpClientFactory httpClientFactory,
	GetNextCoreHandlerServices getNextCoreHandlerServices)
{
	private readonly ILogger<GetNextCoreHandler> _logger = logger;
	private readonly HttpClient _httpClient = httpClientFactory.CreateClient();
	private readonly GetNextCoreHandlerServices _getNextCoreHandlerServices = getNextCoreHandlerServices;

	[Function("GetNextCoreForPod123Handler")]
	public async Task Run(
		[ServiceBusTrigger("%GetNextCoreTopicName%", "%GetNextCoreForPod123SubscriptionName%", Connection = "ServiceBusConnectionString")] ServiceBusReceivedMessage message,
		ServiceBusMessageActions messageActions)
	{

		_logger.LogInformation("Message ID: {id}", message.MessageId);

		OrderNextCoreMessage? orderNextCoreMessage = JsonSerializer.Deserialize<OrderNextCoreMessage>(message.Body);
		if (orderNextCoreMessage == null)
		{
			_logger.LogError("Failed to deserialize the message body.");
			await messageActions.DeadLetterMessageAsync(message);
			return;
		}

		_logger.LogInformation("Get next core for pod {podId}", orderNextCoreMessage.PodId);

		IResponse getNextCoreInfoResponse = await _getNextCoreHandlerServices.GetNextCoreAsync(_httpClient, orderNextCoreMessage);
		if (getNextCoreInfoResponse is StandardResponse response)
		{
			orderNextCoreMessage.CoreId = response.Extensions!["CoreId"].ToString();
			orderNextCoreMessage.FinishedProductId = response.Extensions!["FinishedProductId"].ToString();
		}
		else
		{
			await messageActions.DeadLetterMessageAsync(message);
			return;
		}

		IResponse orderNextCoreResponse = await _getNextCoreHandlerServices.OrderNextCoreAsync(orderNextCoreMessage, message.MessageId);
		if (orderNextCoreResponse is ProblemDetails)
		{
			await messageActions.DeadLetterMessageAsync(message);
			return;
		}

		// Complete the message
		await messageActions.CompleteMessageAsync(message);

	}
}
```

### Step 17: Test the Azure Function locally

1. From the [Azure Portal](https://portal.azure.com), search for `sbns-remanufacturing` and select the appropriate Service Bus Namespace.
2. Click on the **Topics** tab.
3. Click on the `sbt-ordernextcore...` topic.
4. Click on **Shared access policies**.
5. Click on `GetNextCoreSender` and copy the **Primary Connection String**.
6. In the `local.settings.json` file of the `GetNextCore` project, add the following key/value pairs:
   - ServiceBusConnectionString - The primary key you just copied.
   - GetNextCoreTopicName - The name of the GetNextCore topic from the portal.
7. Right-click the `GetNextCore` project and select **Set as Startup Project**.
8. Press **F5** to start the Azure Function app locally.
9. Copy the **GetNextCore** endpoint.
10. Open Postman and enter the **GetNextCore** in the **Enter URL or paste text** field.
11. Change the HTTP method to **POST**.
12. Go to the **Body** tab.
13. Select **raw**.
14. Paste the following into the request body field:

```json
{
    "MessageId": "message-123",
    "MessageType": "GetNextCore",
    "PodId": "Pod123"
}
```

15. Click the **Send** button. You should receive a **201 Created** response with a response body similar to:

```json
{
    "type": "https://httpstatuses.com/201",
    "title": "Request for next core id sent.",
    "status": 201,
    "detail": "The request for the next core id has been sent to the Production Schedule.",
    "instance": "0HN547NP89O2R:00000001",
    "extensions": {
        "PodId": "Pod123"
    }
}
```

16. Back in the [Azure Portal](https://portal.azure.com), click the **Service Bus Explorer** menu item (assuming you are still in the sbt-getnextcore topic from before).
17. Select the `sbts-GetNextCore` subscription and then click the **Peak from start** button. You should see the message that was just sent to the Service Bus topic.

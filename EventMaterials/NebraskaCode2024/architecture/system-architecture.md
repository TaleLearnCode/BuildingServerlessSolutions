[Design and Develop a Serverless Event-Driven Microservice-Based Solution](https://github.com/TaleLearnCode/EDAMicroserviceWorkshop) \ [Nebraska.Code 2024](README.md)  \ [Architecture](README.md)  \

# System Architecture

Here is a high-level overview of the Cool Revive Technologies remanufacturing processing system architecture.

### Event Sources

- **Production Control Schedule**: Determines the units to be built during the production day.
- **Core Arrival**: Signals the core unit's arrival.
- **Part Repair/Replacement**: Generates events for repair or replacement needs.

### Azure Functions (Microservices)

Each Azure Function app corresponds to a specific step:

- **OrderProcessing**: Orders the next core unit.
- **CoreReceiving**: Receives and updates inventory.
- **Disassembly**: Updates inventory status.
- **PartsInspection**: Determines part status.
- **PartRepair**: Sends repair requests.
- **PartOrdering**: Places part orders.
- **PartReceiving**: Updates inventory after part arrival.
- **Assembly**: Assembles the refrigerator.
- **QualityControl**: Tests the refrigerator.
- **ProcessCompletion**: Completes the process.

### Azure Event Grid

- Connects microservices via events.
- Publishes and consumes events.
- Orchestrates the workflow.

### Azure Cosmos DB

- Stores inventory data.
- It is accessed by relevant functions.

### Event Flow

- Events trigger functions sequentially.
- Each function performs its task.
- Quality control and completion finalize the process.

## Conclusion

This architecture promotes scalability, cost efficiency, and agility.
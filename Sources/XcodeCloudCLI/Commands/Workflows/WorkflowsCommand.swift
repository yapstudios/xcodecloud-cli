import ArgumentParser
import Foundation
import XcodeCloudKit

struct WorkflowsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "workflows",
        abstract: "Manage CI workflows",
        discussion: """
            Workflows define how your code is built, tested, and distributed.
            Each workflow belongs to a CI product.

            EXAMPLES
              List workflows for a product:
                $ xcodecloud workflows list <product-id>

              Get workflow details:
                $ xcodecloud workflows get <workflow-id>

              List workflows in table format:
                $ xcodecloud workflows list <product-id> -o table
            """,
        subcommands: [
            WorkflowsListCommand.self,
            WorkflowsGetCommand.self
        ]
    )
}

struct WorkflowsListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List workflows for a CI product"
    )

    @OptionGroup var options: GlobalOptions

    @Argument(help: "Product ID")
    var productId: String

    @Option(name: .long, help: "Maximum number of results (default: 25)")
    var limit: Int?

    mutating func run() throws {
        let client: APIClient
        do {
            client = try options.apiClient()
        } catch let error as CLIError {
            printError(error.localizedDescription)
            throw ExitCode(rawValue: error.exitCode)
        }

        let prodId = productId
        let limitVal = limit
        let verbose = options.verbose

        do {
            printVerbose("Fetching workflows for product \(prodId)...", verbose: verbose)
            let response = try runAsync {
                try await client.listWorkflows(productId: prodId, limit: limitVal)
            }

            let formatter = options.outputFormatter()

            if options.output == .json {
                let output = try formatter.formatRawJSON(response)
                print(output)
            } else {
                let output = try formatter.format(response.data)
                print(output)
            }
        } catch let error as CLIError {
            printError(error.localizedDescription)
            throw ExitCode(rawValue: error.exitCode)
        }
    }
}

struct WorkflowsGetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Get details for a workflow"
    )

    @OptionGroup var options: GlobalOptions

    @Argument(help: "Workflow ID")
    var id: String

    mutating func run() throws {
        let client: APIClient
        do {
            client = try options.apiClient()
        } catch let error as CLIError {
            printError(error.localizedDescription)
            throw ExitCode(rawValue: error.exitCode)
        }

        let workflowId = id
        let verbose = options.verbose

        do {
            printVerbose("Fetching workflow \(workflowId)...", verbose: verbose)
            let response = try runAsync {
                try await client.getWorkflow(id: workflowId)
            }

            let formatter = options.outputFormatter()

            if options.output == .json {
                let output = try formatter.formatRawJSON(response)
                print(output)
            } else {
                let output = try formatter.format(response.data)
                print(output)
            }
        } catch let error as CLIError {
            printError(error.localizedDescription)
            throw ExitCode(rawValue: error.exitCode)
        }
    }
}

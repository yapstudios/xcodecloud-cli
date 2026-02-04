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
        abstract: "List workflows for a CI product",
        discussion: """
            FILTERING
              --name <text>    Filter workflows by name (case-insensitive substring match)
              --enabled        Show only enabled workflows
              --disabled       Show only disabled workflows

            EXAMPLES
              List all workflows:
                $ xcodecloud workflows list <product-id> -o table

              Filter by name:
                $ xcodecloud workflows list <product-id> --name Release

              Show only enabled workflows:
                $ xcodecloud workflows list <product-id> --enabled
            """
    )

    @OptionGroup var options: GlobalOptions

    @Argument(help: "Product ID")
    var productId: String

    @Option(name: .long, help: "Maximum number of results (default: 25)")
    var limit: Int?

    @Flag(name: .long, help: "Fetch all pages of results")
    var all: Bool = false

    @Option(name: .long, help: "Filter by name (case-insensitive substring match)")
    var name: String?

    @Flag(name: .long, help: "Show only enabled workflows")
    var enabled: Bool = false

    @Flag(name: .long, help: "Show only disabled workflows")
    var disabled: Bool = false

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
        let fetchAll = all
        let nameFilter = name
        let showEnabled = enabled
        let showDisabled = disabled

        do {
            printVerbose("Fetching workflows for product \(prodId)...", verbose: verbose)
            let response = try runAsync {
                if fetchAll {
                    return try await client.listAllWorkflows(productId: prodId, limit: limitVal)
                }
                return try await client.listWorkflows(productId: prodId, limit: limitVal)
            }

            var filtered = response.data
            if let nameFilter {
                filtered = filtered.filter {
                    $0.attributes?.name?.localizedCaseInsensitiveContains(nameFilter) == true
                }
            }
            if showEnabled {
                filtered = filtered.filter { $0.attributes?.isEnabled == true }
            } else if showDisabled {
                filtered = filtered.filter { $0.attributes?.isEnabled != true }
            }

            let formatter = options.outputFormatter()

            if options.output == .json {
                let output = try formatter.formatRawJSON(response)
                print(output)
            } else {
                let output = try formatter.format(filtered)
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

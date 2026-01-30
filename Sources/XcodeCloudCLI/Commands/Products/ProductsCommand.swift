import ArgumentParser
import Foundation
import XcodeCloudKit

struct ProductsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "products",
        abstract: "Manage CI products",
        discussion: """
            CI products represent your apps and frameworks in Xcode Cloud.
            Each product can have multiple workflows.

            EXAMPLES
              List all products:
                $ xcodecloud products list

              List products in table format:
                $ xcodecloud products list -o table

              Get details for a specific product:
                $ xcodecloud products get <product-id>
            """,
        subcommands: [
            ProductsListCommand.self,
            ProductsGetCommand.self
        ]
    )
}

struct ProductsListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all CI products"
    )

    @OptionGroup var options: GlobalOptions

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

        let limitVal = limit
        let verbose = options.verbose

        do {
            printVerbose("Fetching products...", verbose: verbose)
            let response = try runAsync {
                try await client.listProducts(limit: limitVal)
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

struct ProductsGetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Get details for a CI product"
    )

    @OptionGroup var options: GlobalOptions

    @Argument(help: "Product ID")
    var id: String

    mutating func run() throws {
        let client: APIClient
        do {
            client = try options.apiClient()
        } catch let error as CLIError {
            printError(error.localizedDescription)
            throw ExitCode(rawValue: error.exitCode)
        }

        let productId = id
        let verbose = options.verbose

        do {
            printVerbose("Fetching product \(productId)...", verbose: verbose)
            let response = try runAsync {
                try await client.getProduct(id: productId)
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

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
                $ xcodecloud products list -o table

              Filter by name:
                $ xcodecloud products list --name MyApp

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
        abstract: "List all CI products",
        discussion: """
            FILTERING
              --name <text>    Filter products by name (case-insensitive substring match)
              --type <type>    Filter by product type (APP, FRAMEWORK)

            EXAMPLES
              List all products:
                $ xcodecloud products list -o table

              Filter by name:
                $ xcodecloud products list --name MyApp

              Filter by type:
                $ xcodecloud products list --type APP
            """
    )

    @OptionGroup var options: GlobalOptions

    @Option(name: .long, help: "Maximum number of results (default: 25)")
    var limit: Int?

    @Flag(name: .long, help: "Fetch all pages of results")
    var all: Bool = false

    @Option(name: .long, help: "Filter by name (case-insensitive substring match)")
    var name: String?

    @Option(name: .long, help: "Filter by product type (APP, FRAMEWORK)")
    var type: String?

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
        let fetchAll = all
        let nameFilter = name
        let typeFilter = type?.uppercased()

        do {
            printVerbose("Fetching products...", verbose: verbose)
            let response = try runAsync {
                if fetchAll {
                    return try await client.listAllProducts(limit: limitVal)
                }
                return try await client.listProducts(limit: limitVal)
            }

            var filtered = response.data
            if let nameFilter {
                filtered = filtered.filter {
                    $0.attributes?.name?.localizedCaseInsensitiveContains(nameFilter) == true
                }
            }
            if let typeFilter {
                filtered = filtered.filter {
                    $0.attributes?.productType?.uppercased() == typeFilter
                }
            }

            let formatter = options.outputFormatter()

            if options.output == .json {
                let output = try formatter.formatRawJSON(response)
                print(output)
            } else {
                let rows = filtered.map { product -> [String] in
                    [
                        product.id,
                        product.attributes?.name ?? "-",
                        product.bundleId(from: response.included) ?? product.attributes?.productType ?? "-",
                        formatDate(product.attributes?.createdDate) ?? "-"
                    ]
                }
                let output = formatter.formatTable(headers: ["ID", "NAME", "BUNDLE ID", "CREATED"], rows: rows)
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

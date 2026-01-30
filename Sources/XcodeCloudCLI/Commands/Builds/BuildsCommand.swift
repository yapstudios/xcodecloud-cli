import ArgumentParser
import Foundation
import XcodeCloudKit

struct BuildsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "builds",
        abstract: "Manage build runs",
        discussion: """
            Build runs represent individual executions of a workflow.
            You can list, view, start, and monitor builds.

            BUILD STATUS VALUES
              executionProgress: PENDING, RUNNING, COMPLETE
              completionStatus: SUCCEEDED, FAILED, ERRORED, CANCELED, SKIPPED

            EXAMPLES
              List recent builds:
                $ xcodecloud builds list

              List builds for a workflow:
                $ xcodecloud builds list --workflow <workflow-id>

              Start a new build:
                $ xcodecloud builds start <workflow-id>

              Start a build for a specific branch:
                $ xcodecloud builds start <workflow-id> --branch main

              Get build status:
                $ xcodecloud builds get <build-id>
            """,
        subcommands: [
            BuildsListCommand.self,
            BuildsGetCommand.self,
            BuildsStartCommand.self,
            BuildsActionsCommand.self
        ]
    )
}

struct BuildsListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List build runs"
    )

    @OptionGroup var options: GlobalOptions

    @Option(name: .long, help: "Filter by workflow ID")
    var workflow: String?

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

        let workflowId = workflow
        let limitVal = limit
        let verbose = options.verbose

        do {
            if let wfId = workflowId {
                printVerbose("Fetching builds for workflow \(wfId)...", verbose: verbose)
            } else {
                printVerbose("Fetching all builds...", verbose: verbose)
            }

            let response = try runAsync {
                try await client.listBuildRuns(workflowId: workflowId, limit: limitVal)
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

struct BuildsGetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Get details for a build run"
    )

    @OptionGroup var options: GlobalOptions

    @Argument(help: "Build run ID")
    var id: String

    mutating func run() throws {
        let client: APIClient
        do {
            client = try options.apiClient()
        } catch let error as CLIError {
            printError(error.localizedDescription)
            throw ExitCode(rawValue: error.exitCode)
        }

        let buildId = id
        let verbose = options.verbose

        do {
            printVerbose("Fetching build \(buildId)...", verbose: verbose)
            let response = try runAsync {
                try await client.getBuildRun(id: buildId)
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

struct BuildsStartCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "start",
        abstract: "Start a new build run"
    )

    @OptionGroup var options: GlobalOptions

    @Argument(help: "Workflow ID")
    var workflowId: String

    @Option(name: .long, help: "Branch name to build")
    var branch: String?

    @Option(name: .long, help: "Tag name to build")
    var tag: String?

    mutating func run() throws {
        // Validate that only one of branch or tag is specified
        if branch != nil && tag != nil {
            printError("Cannot specify both --branch and --tag")
            throw ExitCode.failure
        }

        let client: APIClient
        do {
            client = try options.apiClient()
        } catch let error as CLIError {
            printError(error.localizedDescription)
            throw ExitCode(rawValue: error.exitCode)
        }

        let wfId = workflowId
        let verbose = options.verbose
        let quiet = options.quiet

        do {
            let gitReference: GitReference?
            if let branch = branch {
                gitReference = .branch(branch)
            } else if let tag = tag {
                gitReference = .tag(tag)
            } else {
                gitReference = nil
            }

            printVerbose("Starting build for workflow \(wfId)...", verbose: verbose)
            let response = try runAsync {
                try await client.startBuildRun(workflowId: wfId, gitReference: gitReference)
            }

            if !quiet {
                print("Build started")
                print("  Build ID: \(response.data.id)")
                if let number = response.data.attributes?.number {
                    print("  Build number: \(number)")
                }
            }

            let formatter = options.outputFormatter()

            if options.output == .json {
                let output = try formatter.formatRawJSON(response)
                print(output)
            } else if !quiet {
                print("\nRun 'xcodecloud builds get \(response.data.id)' to check status")
            }
        } catch let error as CLIError {
            printError(error.localizedDescription)
            throw ExitCode(rawValue: error.exitCode)
        }
    }
}

struct BuildsActionsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "actions",
        abstract: "List actions for a build run"
    )

    @OptionGroup var options: GlobalOptions

    @Argument(help: "Build run ID")
    var buildId: String

    mutating func run() throws {
        let client: APIClient
        do {
            client = try options.apiClient()
        } catch let error as CLIError {
            printError(error.localizedDescription)
            throw ExitCode(rawValue: error.exitCode)
        }

        let bId = buildId
        let verbose = options.verbose

        do {
            printVerbose("Fetching actions for build \(bId)...", verbose: verbose)
            let response = try runAsync {
                try await client.listBuildActions(buildRunId: bId)
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

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

              Show build errors:
                $ xcodecloud builds errors <build-id>

              Show test failures:
                $ xcodecloud builds tests <build-id>
            """,
        subcommands: [
            BuildsListCommand.self,
            BuildsGetCommand.self,
            BuildsStartCommand.self,
            BuildsActionsCommand.self,
            BuildsErrorsCommand.self,
            BuildsIssuesCommand.self,
            BuildsIssueGetCommand.self,
            BuildsTestsCommand.self,
            BuildsTestResultGetCommand.self
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

struct BuildsErrorsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "errors",
        abstract: "Show errors, issues, and test failures for a build run",
        discussion: """
            Fetches all build actions for a build run and displays:
            - Compiler errors and warnings
            - Test failures

            This is a convenience command that shows everything that went wrong.
            """
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
            // First get all actions for this build
            printVerbose("Fetching actions for build \(bId)...", verbose: verbose)
            let actionsResponse = try runAsync {
                try await client.listBuildActions(buildRunId: bId)
            }

            let failedActions = actionsResponse.data.filter {
                $0.attributes?.completionStatus == "FAILED" ||
                $0.attributes?.completionStatus == "ERRORED"
            }

            var allIssues: [CiIssue] = []
            var failedTests: [CiTestResult] = []

            // Get issues for each failed action
            for action in failedActions {
                printVerbose("Fetching issues for action \(action.id)...", verbose: verbose)
                let issuesResponse = try runAsync {
                    try await client.listIssues(buildActionId: action.id)
                }
                allIssues.append(contentsOf: issuesResponse.data)
            }

            // Get test failures from test actions
            let testActions = actionsResponse.data.filter {
                $0.attributes?.actionType == "TEST"
            }

            for action in testActions {
                printVerbose("Fetching test results for action \(action.id)...", verbose: verbose)
                let testResponse = try runAsync {
                    try await client.listTestResults(buildActionId: action.id)
                }
                let failures = testResponse.data.filter {
                    $0.attributes?.status == "FAILURE" || $0.attributes?.status == "EXPECTED_FAILURE"
                }
                failedTests.append(contentsOf: failures)
            }

            let formatter = options.outputFormatter()

            if options.output == .json {
                // Output structured JSON with actions, issues, and test failures
                struct ErrorReport: Codable {
                    let buildId: String
                    let failedActions: [CiBuildAction]
                    let issues: [CiIssue]
                    let testFailures: [CiTestResult]
                }
                let report = ErrorReport(buildId: bId, failedActions: failedActions, issues: allIssues, testFailures: failedTests)
                let output = try formatter.formatRawJSON(report)
                print(output)
            } else {
                var hasOutput = false

                // Human-readable output
                if !failedActions.isEmpty {
                    hasOutput = true
                    print("Build \(bId) - Failed Actions:")
                    print("")

                    for action in failedActions {
                        print("  \(action.attributes?.name ?? "Unknown") (\(action.attributes?.actionType ?? ""))")
                        print("    Status: \(action.attributes?.completionStatus ?? "Unknown")")
                    }
                }

                if !allIssues.isEmpty {
                    hasOutput = true
                    print("")
                    print("Compiler Issues (\(allIssues.count)):")
                    print("")

                    for issue in allIssues {
                        let issueType = issue.attributes?.issueType ?? "UNKNOWN"
                        let message = issue.attributes?.message ?? "No message"
                        let file = issue.attributes?.fileSource?.path ?? ""
                        let line = issue.attributes?.fileSource?.lineNumber

                        if !file.isEmpty {
                            if let line = line {
                                print("  [\(issueType)] \(file):\(line)")
                            } else {
                                print("  [\(issueType)] \(file)")
                            }
                        } else {
                            print("  [\(issueType)]")
                        }
                        print("    \(message)")
                        print("")
                    }
                }

                if !failedTests.isEmpty {
                    hasOutput = true
                    print("")
                    print("Test Failures (\(failedTests.count)):")
                    print("")

                    for test in failedTests {
                        let className = test.attributes?.className ?? "Unknown"
                        let testName = test.attributes?.name ?? "Unknown"
                        print("  \(className).\(testName)")
                        if let message = test.attributes?.message, !message.isEmpty {
                            let indentedMessage = message.split(separator: "\n").map { "    \($0)" }.joined(separator: "\n")
                            print(indentedMessage)
                        }
                        if let fileSource = test.attributes?.fileSource, let path = fileSource.path {
                            if let line = fileSource.lineNumber {
                                print("    at \(path):\(line)")
                            } else {
                                print("    at \(path)")
                            }
                        }
                        print("")
                    }
                }

                if !hasOutput {
                    print("No errors found for build \(bId)")

                    // Show summary of actions
                    let actionSummary = actionsResponse.data.map {
                        "\($0.attributes?.name ?? "Unknown"): \($0.attributes?.completionStatus ?? "Unknown")"
                    }.joined(separator: ", ")
                    print("Actions: \(actionSummary)")
                }
            }
        } catch let error as CLIError {
            printError(error.localizedDescription)
            throw ExitCode(rawValue: error.exitCode)
        }
    }
}

struct BuildsIssuesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "issues",
        abstract: "List issues for a build action",
        discussion: """
            Lists compiler issues (errors/warnings) for a specific build action.

            NOTE: This takes a build ACTION ID, not a build ID.
            First run 'xcodecloud builds actions <build-id>' to get action IDs.

            For a simpler workflow, use 'xcodecloud builds errors <build-id>'
            which aggregates all issues across all actions.
            """
    )

    @OptionGroup var options: GlobalOptions

    @Argument(help: "Build action ID")
    var actionId: String

    mutating func run() throws {
        let client: APIClient
        do {
            client = try options.apiClient()
        } catch let error as CLIError {
            printError(error.localizedDescription)
            throw ExitCode(rawValue: error.exitCode)
        }

        let aId = actionId
        let verbose = options.verbose

        do {
            printVerbose("Fetching issues for action \(aId)...", verbose: verbose)
            let response = try runAsync {
                try await client.listIssues(buildActionId: aId)
            }

            let formatter = options.outputFormatter()

            if options.output == .json {
                let output = try formatter.formatRawJSON(response)
                print(output)
            } else {
                if response.data.isEmpty {
                    print("No issues found for action \(aId)")
                } else {
                    let output = try formatter.format(response.data)
                    print(output)
                }
            }
        } catch let error as CLIError {
            printError(error.localizedDescription)
            throw ExitCode(rawValue: error.exitCode)
        }
    }
}

struct BuildsTestsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tests",
        abstract: "Show test results for a build run",
        discussion: """
            Fetches test results from all test actions in a build run.
            Shows passed, failed, and skipped tests.

            Use --failures to show only failed tests.
            """
    )

    @OptionGroup var options: GlobalOptions

    @Argument(help: "Build run ID")
    var buildId: String

    @Flag(name: .long, help: "Show only failed tests")
    var failures: Bool = false

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
        let showOnlyFailures = failures

        do {
            // First get all actions for this build
            printVerbose("Fetching actions for build \(bId)...", verbose: verbose)
            let actionsResponse = try runAsync {
                try await client.listBuildActions(buildRunId: bId)
            }

            // Filter to test actions
            let testActions = actionsResponse.data.filter {
                $0.attributes?.actionType == "TEST"
            }

            if testActions.isEmpty {
                print("No test actions found for build \(bId)")
                return
            }

            var allTestResults: [CiTestResult] = []

            // Get test results for each test action
            for action in testActions {
                printVerbose("Fetching test results for action \(action.id) (\(action.attributes?.name ?? ""))...", verbose: verbose)
                let testResponse = try runAsync {
                    try await client.listTestResults(buildActionId: action.id)
                }
                allTestResults.append(contentsOf: testResponse.data)
            }

            // Filter if needed
            let resultsToShow: [CiTestResult]
            if showOnlyFailures {
                resultsToShow = allTestResults.filter {
                    $0.attributes?.status == "FAILURE" || $0.attributes?.status == "EXPECTED_FAILURE"
                }
            } else {
                resultsToShow = allTestResults
            }

            let formatter = options.outputFormatter()

            if options.output == .json {
                struct TestReport: Codable {
                    let buildId: String
                    let totalTests: Int
                    let passed: Int
                    let failed: Int
                    let skipped: Int
                    let results: [CiTestResult]
                }

                let passed = allTestResults.filter { $0.attributes?.status == "SUCCESS" }.count
                let failed = allTestResults.filter { $0.attributes?.status == "FAILURE" || $0.attributes?.status == "EXPECTED_FAILURE" }.count
                let skipped = allTestResults.filter { $0.attributes?.status == "SKIPPED" }.count

                let report = TestReport(
                    buildId: bId,
                    totalTests: allTestResults.count,
                    passed: passed,
                    failed: failed,
                    skipped: skipped,
                    results: resultsToShow
                )
                let output = try formatter.formatRawJSON(report)
                print(output)
            } else {
                // Summary
                let passed = allTestResults.filter { $0.attributes?.status == "SUCCESS" }.count
                let failed = allTestResults.filter { $0.attributes?.status == "FAILURE" || $0.attributes?.status == "EXPECTED_FAILURE" }.count
                let skipped = allTestResults.filter { $0.attributes?.status == "SKIPPED" }.count

                print("Test Results for Build \(bId)")
                print("==============================")
                print("Total: \(allTestResults.count)  Passed: \(passed)  Failed: \(failed)  Skipped: \(skipped)")
                print("")

                if resultsToShow.isEmpty {
                    if showOnlyFailures {
                        print("No test failures!")
                    } else {
                        print("No test results found.")
                    }
                } else {
                    // Group by status for better readability
                    let failedTests = resultsToShow.filter { $0.attributes?.status == "FAILURE" || $0.attributes?.status == "EXPECTED_FAILURE" }
                    let passedTests = resultsToShow.filter { $0.attributes?.status == "SUCCESS" }
                    let skippedTests = resultsToShow.filter { $0.attributes?.status == "SKIPPED" }

                    if !failedTests.isEmpty {
                        print("FAILURES (\(failedTests.count)):")
                        print("")
                        for test in failedTests {
                            let className = test.attributes?.className ?? "Unknown"
                            let testName = test.attributes?.name ?? "Unknown"
                            print("  \(className).\(testName)")
                            if let message = test.attributes?.message, !message.isEmpty {
                                // Indent multi-line messages
                                let indentedMessage = message.split(separator: "\n").map { "    \($0)" }.joined(separator: "\n")
                                print(indentedMessage)
                            }
                            if let fileSource = test.attributes?.fileSource, let path = fileSource.path {
                                if let line = fileSource.lineNumber {
                                    print("    at \(path):\(line)")
                                } else {
                                    print("    at \(path)")
                                }
                            }
                            print("")
                        }
                    }

                    if !showOnlyFailures {
                        if !skippedTests.isEmpty {
                            print("SKIPPED (\(skippedTests.count)):")
                            for test in skippedTests {
                                let className = test.attributes?.className ?? "Unknown"
                                let testName = test.attributes?.name ?? "Unknown"
                                print("  \(className).\(testName)")
                            }
                            print("")
                        }

                        if !passedTests.isEmpty && passedTests.count <= 20 {
                            print("PASSED (\(passedTests.count)):")
                            for test in passedTests {
                                let className = test.attributes?.className ?? "Unknown"
                                let testName = test.attributes?.name ?? "Unknown"
                                print("  \(className).\(testName)")
                            }
                        } else if !passedTests.isEmpty {
                            print("PASSED: \(passedTests.count) tests (use -o table to see all)")
                        }
                    }
                }
            }
        } catch let error as CLIError {
            printError(error.localizedDescription)
            throw ExitCode(rawValue: error.exitCode)
        }
    }
}

struct BuildsIssueGetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "issue",
        abstract: "Get details for a specific issue by ID"
    )

    @OptionGroup var options: GlobalOptions

    @Argument(help: "Issue ID")
    var id: String

    mutating func run() throws {
        let client: APIClient
        do {
            client = try options.apiClient()
        } catch let error as CLIError {
            printError(error.localizedDescription)
            throw ExitCode(rawValue: error.exitCode)
        }

        let issueId = id
        let verbose = options.verbose

        do {
            printVerbose("Fetching issue \(issueId)...", verbose: verbose)
            let response = try runAsync {
                try await client.getIssue(id: issueId)
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

struct BuildsTestResultGetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "test-result",
        abstract: "Get details for a specific test result by ID"
    )

    @OptionGroup var options: GlobalOptions

    @Argument(help: "Test result ID")
    var id: String

    mutating func run() throws {
        let client: APIClient
        do {
            client = try options.apiClient()
        } catch let error as CLIError {
            printError(error.localizedDescription)
            throw ExitCode(rawValue: error.exitCode)
        }

        let testResultId = id
        let verbose = options.verbose

        do {
            printVerbose("Fetching test result \(testResultId)...", verbose: verbose)
            let response = try runAsync {
                try await client.getTestResult(id: testResultId)
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

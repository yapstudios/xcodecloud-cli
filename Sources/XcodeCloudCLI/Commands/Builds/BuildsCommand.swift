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

              List failed builds:
                $ xcodecloud builds list --workflow <workflow-id> --status failed

              Show build errors:
                $ xcodecloud builds errors <build-id>

              Show test failures:
                $ xcodecloud builds tests <build-id>
            """,
        subcommands: [
            BuildsListCommand.self,
            BuildsGetCommand.self,
            BuildsStartCommand.self,
            BuildsWatchCommand.self,
            BuildsLogsCommand.self,
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
        abstract: "List build runs",
        discussion: """
            FILTERING
              --status <status>  Filter by completion status
                                 Values: SUCCEEDED, FAILED, ERRORED, CANCELED, SKIPPED
              --running          Show only builds currently in progress

            EXAMPLES
              List recent builds:
                $ xcodecloud builds list -o table

              List failed builds for a workflow:
                $ xcodecloud builds list --workflow <id> --status failed

              List running builds:
                $ xcodecloud builds list --running

              List all builds (paginate through everything):
                $ xcodecloud builds list --workflow <id> --all
            """
    )

    @OptionGroup var options: GlobalOptions

    @Option(name: .long, help: "Filter by workflow ID")
    var workflow: String?

    @Option(name: .long, help: "Maximum number of results (default: 25)")
    var limit: Int?

    @Flag(name: .long, help: "Fetch all pages of results")
    var all: Bool = false

    @Option(name: .long, help: "Filter by completion status (SUCCEEDED, FAILED, ERRORED, CANCELED, SKIPPED)")
    var status: String?

    @Flag(name: .long, help: "Show only builds currently in progress")
    var running: Bool = false

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
        let fetchAll = all
        let statusFilter = status?.uppercased()
        let showRunning = running

        do {
            if let wfId = workflowId {
                printVerbose("Fetching builds for workflow \(wfId)...", verbose: verbose)
            } else {
                printVerbose("Fetching all builds...", verbose: verbose)
            }

            let response = try runAsync {
                if fetchAll {
                    return try await client.listAllBuildRuns(workflowId: workflowId, limit: limitVal)
                }
                return try await client.listBuildRuns(workflowId: workflowId, limit: limitVal)
            }

            var filtered = response.data
            if showRunning {
                filtered = filtered.filter {
                    $0.attributes?.executionProgress != "COMPLETE"
                }
            } else if let statusFilter {
                filtered = filtered.filter {
                    $0.attributes?.completionStatus?.uppercased() == statusFilter
                }
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

struct BuildsWatchCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "watch",
        abstract: "Watch a build run until completion",
        discussion: """
            Polls the build status and displays live progress updates.
            Sends a macOS notification when the build completes.
            Exits with code 0 on success, 1 on failure.

            EXAMPLES
              Watch a build:
                $ xcodecloud builds watch <build-id>

              Watch with faster polling:
                $ xcodecloud builds watch <build-id> --interval 5

              Watch without notification:
                $ xcodecloud builds watch <build-id> --no-notify
            """
    )

    @OptionGroup var options: GlobalOptions

    @Argument(help: "Build run ID to watch")
    var id: String

    @Option(name: .long, help: "Poll interval in seconds (default: 10)")
    var interval: Int = 10

    @Flag(name: .long, inversion: .prefixedNo, help: "Send macOS notification on completion (default: true)")
    var notify: Bool = true

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
        let quiet = options.quiet
        let shouldNotify = notify && !quiet
        let pollInterval = max(interval, 1)
        let isTTY = TerminalUI.isInteractiveTerminal

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let dateFormatterNoFrac = ISO8601DateFormatter()
        dateFormatterNoFrac.formatOptions = [.withInternetDateTime]

        func parseDate(_ string: String?) -> Date? {
            guard let string else { return nil }
            return dateFormatter.date(from: string) ?? dateFormatterNoFrac.date(from: string)
        }

        func formatDuration(_ seconds: Int) -> String {
            if seconds < 60 {
                return "\(seconds)s"
            } else {
                let m = seconds / 60
                let s = seconds % 60
                return s > 0 ? "\(m)m \(s)s" : "\(m)m"
            }
        }

        func colorStatus(_ status: String) -> String {
            switch status {
            case "SUCCEEDED": return TerminalUI.green(status)
            case "FAILED", "ERRORED": return TerminalUI.red(status)
            case "CANCELED", "SKIPPED": return TerminalUI.yellow(status)
            case "RUNNING": return TerminalUI.cyan(status)
            default: return TerminalUI.dim(status)
            }
        }

        var previousLineCount = 0

        do {
            while true {
                printVerbose("Polling build \(buildId)...", verbose: verbose)

                let response = try runAsync {
                    try await client.getBuildRun(id: buildId)
                }
                let build = response.data
                let attrs = build.attributes

                let progress = attrs?.executionProgress ?? "UNKNOWN"
                let status = attrs?.completionStatus
                let buildNumber = attrs?.number.map { "#\($0)" } ?? buildId

                // Calculate elapsed time
                let elapsed: String
                if progress == "COMPLETE",
                   let started = parseDate(attrs?.startedDate),
                   let finished = parseDate(attrs?.finishedDate) {
                    elapsed = formatDuration(Int(finished.timeIntervalSince(started)))
                } else if let started = parseDate(attrs?.startedDate) {
                    elapsed = formatDuration(Int(Date().timeIntervalSince(started)))
                } else {
                    elapsed = "waiting..."
                }

                // Fetch actions
                let actionsResponse = try runAsync {
                    try await client.listBuildActions(buildRunId: buildId)
                }
                let actions = actionsResponse.data

                if progress == "COMPLETE" {
                    // Final output
                    let statusText = status ?? "UNKNOWN"

                    if quiet {
                        // Quiet mode: just exit with appropriate code
                        if statusText == "SUCCEEDED" {
                            throw ExitCode.success
                        } else {
                            throw ExitCode.failure
                        }
                    }

                    // Clear any previous live output
                    if isTTY && previousLineCount > 0 {
                        for _ in 0..<previousLineCount {
                            TerminalUI.clearLine()
                            TerminalUI.moveCursorUp(1)
                        }
                        TerminalUI.clearLine()
                    }

                    // Print final summary
                    print("Build \(buildNumber) \(colorStatus(statusText)) (\(elapsed))")
                    for action in actions {
                        let name = action.attributes?.name ?? "Unknown"
                        let actionStatus = action.attributes?.completionStatus ?? action.attributes?.executionProgress ?? "-"
                        print("  \(name)  \(colorStatus(actionStatus))")
                    }

                    if shouldNotify {
                        sendNotification(
                            title: "Xcode Cloud",
                            message: "Build \(buildNumber) \(statusText.lowercased()) (\(elapsed))"
                        )
                        if !quiet {
                            print("  Notification sent.")
                        }
                    }

                    if statusText == "SUCCEEDED" {
                        throw ExitCode.success
                    } else {
                        throw ExitCode.failure
                    }
                }

                // Build still in progress
                if quiet {
                    // Quiet mode: just sleep and continue
                    sleep(UInt32(pollInterval))
                    continue
                }

                if isTTY {
                    // Clear previous output
                    if previousLineCount > 0 {
                        for _ in 0..<previousLineCount {
                            TerminalUI.clearLine()
                            TerminalUI.moveCursorUp(1)
                        }
                        TerminalUI.clearLine()
                    }

                    // Render status block
                    var lines = [String]()
                    lines.append("Watching build \(buildNumber)...")
                    lines.append("  Status: \(colorStatus(progress)) (\(elapsed))")

                    if !actions.isEmpty {
                        lines.append("  Actions:")
                        for action in actions {
                            let name = action.attributes?.name ?? "Unknown"
                            let actionProgress = action.attributes?.completionStatus ?? action.attributes?.executionProgress ?? "-"
                            lines.append("    \(name)  \(colorStatus(actionProgress))")
                        }
                    }

                    for line in lines {
                        print(line)
                    }
                    previousLineCount = lines.count
                } else {
                    // Non-TTY: one line per poll
                    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                    print("[\(timestamp)] \(progress) (\(elapsed))")
                }

                sleep(UInt32(pollInterval))
            }
        } catch let exitCode as ExitCode {
            throw exitCode
        } catch let error as CLIError {
            printError(error.localizedDescription)
            throw ExitCode(rawValue: error.exitCode)
        }
    }
}

struct BuildsLogsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "logs",
        abstract: "List or download build logs",
        discussion: """
            Lists log bundle artifacts for all actions in a build run.
            Use --download to download them.

            EXAMPLES
              List logs for a build:
                $ xcodecloud builds logs <build-id>

              Download all logs:
                $ xcodecloud builds logs <build-id> --download

              Download logs to a specific directory:
                $ xcodecloud builds logs <build-id> --download --dir ./logs
            """
    )

    @OptionGroup var options: GlobalOptions

    @Argument(help: "Build run ID")
    var buildId: String

    @Flag(name: .long, help: "Download the log bundles")
    var download: Bool = false

    @Option(name: [.customShort("d"), .customLong("dir")], help: "Output directory for downloads (default: current directory)")
    var outputDir: String = "."

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
        let quiet = options.quiet
        let shouldDownload = download
        let outDir = outputDir

        do {
            // Fetch build info for display
            printVerbose("Fetching build \(bId)...", verbose: verbose)
            let buildResponse = try runAsync {
                try await client.getBuildRun(id: bId)
            }
            let buildNumber = buildResponse.data.attributes?.number.map { "#\($0)" } ?? bId

            // Fetch all actions
            printVerbose("Fetching actions for build \(bId)...", verbose: verbose)
            let actionsResponse = try runAsync {
                try await client.listBuildActions(buildRunId: bId)
            }

            // Collect log artifacts grouped by action
            struct LogEntry {
                let action: CiBuildAction
                let artifact: CiArtifact
            }

            var logEntries: [LogEntry] = []

            for action in actionsResponse.data {
                printVerbose("Fetching artifacts for action \(action.id)...", verbose: verbose)
                let artifactsResponse = try runAsync {
                    try await client.listArtifacts(buildActionId: action.id)
                }
                let logs = artifactsResponse.data.filter {
                    $0.attributes?.fileType == "LOG_BUNDLE"
                }
                for artifact in logs {
                    logEntries.append(LogEntry(action: action, artifact: artifact))
                }
            }

            guard !logEntries.isEmpty else {
                if !quiet {
                    print("No logs found for build \(buildNumber)")
                }
                return
            }

            if shouldDownload {
                let expandedOutputDir = (outDir as NSString).expandingTildeInPath
                try FileManager.default.createDirectory(
                    at: URL(fileURLWithPath: expandedOutputDir),
                    withIntermediateDirectories: true
                )

                if !quiet {
                    print("Downloading logs for build \(buildNumber)...")
                }

                for entry in logEntries {
                    guard let urlString = entry.artifact.attributes?.downloadUrl,
                          let url = URL(string: urlString) else {
                        continue
                    }

                    let fileName = entry.artifact.attributes?.fileName ?? "\(entry.artifact.id).zip"
                    let destinationURL = URL(fileURLWithPath: expandedOutputDir).appendingPathComponent(fileName)

                    if !quiet {
                        let size = entry.artifact.attributes?.fileSize.map { formatFileSize($0) } ?? ""
                        print("  \(fileName)  (\(size))")
                    }

                    printVerbose("Downloading from \(urlString)...", verbose: verbose)
                    try runAsync {
                        try await client.downloadArtifact(url: url, to: destinationURL)
                    }
                }

                if !quiet {
                    print("Downloaded \(logEntries.count) file(s) to \(expandedOutputDir)")
                }
            } else {
                // List mode
                let formatter = options.outputFormatter()

                if options.output == .json {
                    let artifacts = logEntries.map { $0.artifact }
                    let output = try formatter.formatRawJSON(artifacts)
                    print(output)
                } else {
                    print("Build \(buildNumber) - Logs:")
                    for entry in logEntries {
                        let actionName = entry.action.attributes?.name ?? "Unknown"
                        let fileName = entry.artifact.attributes?.fileName ?? "Unknown"
                        let size = entry.artifact.attributes?.fileSize.map { formatFileSize($0) } ?? ""
                        print("  \(actionName)")
                        print("    \(fileName)  (\(size))")
                    }
                }
            }
        } catch let error as CLIError {
            printError(error.localizedDescription)
            throw ExitCode(rawValue: error.exitCode)
        }
    }
}

private func formatFileSize(_ bytes: Int) -> String {
    let units = ["B", "KB", "MB", "GB"]
    var size = Double(bytes)
    var unitIndex = 0

    while size >= 1024 && unitIndex < units.count - 1 {
        size /= 1024
        unitIndex += 1
    }

    if unitIndex == 0 {
        return "\(bytes) B"
    }
    return String(format: "%.1f %@", size, units[unitIndex])
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

import ArgumentParser
import Foundation
import XcodeCloudKit

struct InteractiveCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "interactive",
        abstract: "Interactive mode - navigate with arrow keys",
        shouldDisplay: false
    )

    @OptionGroup var options: GlobalOptions

    mutating func run() throws {
        guard TerminalUI.isInteractiveTerminal else {
            print("Interactive mode requires a TTY. Use subcommands directly.")
            print("Run 'xcodecloud --help' for usage.")
            throw ExitCode.failure
        }

        let client: APIClient
        do {
            client = try options.apiClient()
        } catch let error as CLIError {
            printError(error.localizedDescription)
            throw ExitCode(rawValue: error.exitCode)
        }

        print(TerminalUI.bold("Xcode Cloud CLI") + " " + TerminalUI.dim("v\(XcodeCloud.configuration.version)"))
        print(TerminalUI.dim("Tip: Run 'xcodecloud --help' for non-interactive commands."))
        print(TerminalUI.dim("Docs: https://github.com/yapstudios/xcodecloud-cli"))
        print("")

        try topLevelMenu(client: client)
    }

    // MARK: - Loading helper

    /// Show a loading message, run the block, then erase the loading message
    private func withLoading<T>(_ message: String, _ block: () throws -> T) throws -> T {
        TerminalUI.writeLine(TerminalUI.dim(message))
        let result = try block()
        // Erase the loading line
        TerminalUI.moveCursorUp(1)
        TerminalUI.clearLine()
        // Move cursor back to start of cleared line
        TerminalUI.writeFlush("\r")
        return result
    }

    // MARK: - Top Level

    private func topLevelMenu(client: APIClient) throws {
        while true {
            let choice: Choice
            do {
                choice = try SelectPrompt.run(
                    prompt: "What would you like to do?",
                    choices: [
                        Choice(label: "Products", value: "products", description: "- Browse apps & frameworks"),
                        Choice(label: "Auth", value: "auth", description: "- Check credentials"),
                        Choice(label: "Exit", value: "exit"),
                    ]
                )
            } catch is SelectPromptError {
                return
            }

            switch choice.value {
            case "products":
                try productsMenu(client: client)
            case "auth":
                try authCheck(client: client)
            case "exit":
                return
            default:
                break
            }
        }
    }

    // MARK: - Auth

    private func authCheck(client: APIClient) throws {
        do {
            let response = try withLoading("Checking credentials...") {
                try runAsync { try await client.listProducts(limit: 1) }
            }
            let total = response.meta?.paging?.total ?? 0
            print("Credentials are valid")
            print("  Found \(total) CI product(s)")
        } catch let error as CLIError {
            printError(error.localizedDescription)
        }
        print("")
    }

    // MARK: - Products

    private func productsMenu(client: APIClient) throws {
        let response = try withLoading("Fetching products...") {
            try runAsync { try await client.listProducts(limit: 50) }
        }

        guard !response.data.isEmpty else {
            print("No products found.")
            print("")
            return
        }

        var allProducts = response.data
        var allIncluded = response.included
        var nextURL = response.links?.next
        var cursorIndex = 0

        while true {
            var choices = allProducts.sorted { ($0.attributes?.name ?? "") < ($1.attributes?.name ?? "") }.map { product in
                let name = product.attributes?.name ?? "Unknown"
                let bundleId = product.bundleId(from: allIncluded)
                let desc = bundleId ?? product.attributes?.productType ?? ""
                return Choice(label: name, value: product.id, description: "- \(desc)")
            }
            if nextURL != nil {
                choices.append(Choice(label: "Load more...", value: "loadmore"))
            }
            choices.append(Choice(label: "Back", value: "back"))

            let choice: Choice
            do {
                choice = try SelectPrompt.run(prompt: "Select a product:", choices: choices, initialSelection: cursorIndex)
            } catch is SelectPromptError {
                return
            }

            cursorIndex = 0

            if choice.value == "back" { return }

            if choice.value == "loadmore", let url = nextURL {
                let previousCount = allProducts.count
                let nextResponse: APIListResponse<CiProduct> = try withLoading("Loading more...") {
                    try runAsync { try await client.fetchNextPage(url) }
                }
                allProducts.append(contentsOf: nextResponse.data)
                if let included = nextResponse.included {
                    allIncluded = (allIncluded ?? []) + included
                }
                nextURL = nextResponse.links?.next
                cursorIndex = previousCount // jump to first new item
                continue
            }

            try productActionsMenu(client: client, productId: choice.value, productName: choice.label)
        }
    }

    private func productActionsMenu(client: APIClient, productId: String, productName: String) throws {
        while true {
            let choice: Choice
            do {
                choice = try SelectPrompt.run(
                    prompt: "\(productName) -",
                    choices: [
                        Choice(label: "List workflows", value: "workflows"),
                        Choice(label: "Back", value: "back"),
                    ]
                )
            } catch is SelectPromptError {
                return
            }

            guard choice.value != "back" else { return }

            if choice.value == "workflows" {
                try workflowsMenu(client: client, productId: productId, productName: productName)
            }
        }
    }

    // MARK: - Workflows

    private func workflowsMenu(client: APIClient, productId: String, productName: String) throws {
        let response = try withLoading("Fetching workflows...") {
            try runAsync { try await client.listWorkflows(productId: productId, limit: 50) }
        }

        guard !response.data.isEmpty else {
            print("No workflows found for \(productName).")
            print("")
            return
        }

        var allWorkflows = response.data
        var nextURL = response.links?.next
        var cursorIndex = 0

        while true {
            var choices = allWorkflows.map { workflow in
                let name = workflow.attributes?.name ?? "Unknown"
                let enabled = workflow.attributes?.isEnabled == true ? "" : " (disabled)"
                return Choice(label: name, value: workflow.id, description: enabled.isEmpty ? nil : enabled)
            }
            if nextURL != nil {
                choices.append(Choice(label: "Load more...", value: "loadmore"))
            }
            choices.append(Choice(label: "Back", value: "back"))

            let choice: Choice
            do {
                choice = try SelectPrompt.run(prompt: "Select a workflow:", choices: choices, initialSelection: cursorIndex)
            } catch is SelectPromptError {
                return
            }

            cursorIndex = 0

            if choice.value == "back" { return }

            if choice.value == "loadmore", let url = nextURL {
                let previousCount = allWorkflows.count
                let nextResponse: APIListResponse<CiWorkflow> = try withLoading("Loading more...") {
                    try runAsync { try await client.fetchNextPage(url) }
                }
                allWorkflows.append(contentsOf: nextResponse.data)
                nextURL = nextResponse.links?.next
                cursorIndex = previousCount
                continue
            }

            try workflowActionsMenu(client: client, workflowId: choice.value, workflowName: choice.label)
        }
    }

    private func workflowActionsMenu(client: APIClient, workflowId: String, workflowName: String) throws {
        while true {
            let choice: Choice
            do {
                choice = try SelectPrompt.run(
                    prompt: "\(workflowName) -",
                    choices: [
                        Choice(label: "List builds", value: "builds"),
                        Choice(label: "Start build", value: "start"),
                        Choice(label: "Back", value: "back"),
                    ]
                )
            } catch is SelectPromptError {
                return
            }

            switch choice.value {
            case "builds":
                try buildsMenu(client: client, workflowId: workflowId, workflowName: workflowName)
            case "start":
                try startBuild(client: client, workflowId: workflowId)
            default:
                return
            }
        }
    }

    // MARK: - Builds

    private func buildsMenu(client: APIClient, workflowId: String, workflowName: String) throws {
        let response = try withLoading("Fetching builds...") {
            try runAsync { try await client.listBuildRuns(workflowId: workflowId, limit: 15) }
        }

        guard !response.data.isEmpty else {
            print("No builds found for \(workflowName).")
            print("")
            return
        }

        var allBuilds = response.data
        var nextURL = response.links?.next
        var cursorIndex = 0

        while true {
            let sorted = allBuilds.sorted { ($0.attributes?.number ?? 0) > ($1.attributes?.number ?? 0) }
            var choices = sorted.map { build in
                let number = build.attributes?.number.map { "#\($0)" } ?? ""
                let status = build.attributes?.completionStatus ?? build.attributes?.executionProgress ?? "Unknown"
                let commitRaw = build.attributes?.sourceCommit?.message ?? ""
                let commit = commitRaw.components(separatedBy: .newlines).first.map { String($0.prefix(40)) } ?? ""
                let label = "\(number) \(status)"
                let desc = commit.isEmpty ? nil : "- \(commit)"
                return Choice(label: label, value: build.id, description: desc)
            }
            if nextURL != nil {
                choices.append(Choice(label: "Load more...", value: "loadmore"))
            }
            choices.append(Choice(label: "Back", value: "back"))

            let choice: Choice
            do {
                choice = try SelectPrompt.run(prompt: "Select a build:", choices: choices, initialSelection: cursorIndex)
            } catch is SelectPromptError {
                return
            }

            cursorIndex = 0

            if choice.value == "back" { return }

            if choice.value == "loadmore", let url = nextURL {
                let previousCount = allBuilds.count
                let nextResponse: APIListResponse<CiBuildRun> = try withLoading("Loading more...") {
                    try runAsync { try await client.fetchNextPage(url) }
                }
                allBuilds.append(contentsOf: nextResponse.data)
                nextURL = nextResponse.links?.next
                // Sorted descending, so new (older) builds appear at the end
                cursorIndex = previousCount
                continue
            }

            try buildActionsMenu(client: client, buildId: choice.value, buildLabel: choice.label)
        }
    }

    private func buildActionsMenu(client: APIClient, buildId: String, buildLabel: String) throws {
        while true {
            let choice: Choice
            do {
                choice = try SelectPrompt.run(
                    prompt: "\(buildLabel) -",
                    choices: [
                        Choice(label: "Watch build", value: "watch"),
                        Choice(label: "View details", value: "details"),
                        Choice(label: "View actions", value: "actions", description: "- Issues, tests, artifacts per action"),
                        Choice(label: "Show errors", value: "errors"),
                        Choice(label: "Download logs", value: "logs"),
                        Choice(label: "List artifacts", value: "artifacts"),
                        Choice(label: "Back", value: "back"),
                    ]
                )
            } catch is SelectPromptError {
                return
            }

            switch choice.value {
            case "watch":
                try watchBuild(client: client, buildId: buildId)
            case "details":
                try showBuildDetails(client: client, buildId: buildId)
            case "actions":
                try actionsMenu(client: client, buildId: buildId)
            case "errors":
                try showBuildErrors(client: client, buildId: buildId)
            case "logs":
                try downloadLogs(client: client, buildId: buildId)
            case "artifacts":
                try artifactsMenu(client: client, buildId: buildId)
            default:
                return
            }
        }
    }

    private func showBuildDetails(client: APIClient, buildId: String) throws {
        let response = try withLoading("Fetching build details...") {
            try runAsync { try await client.getBuildRun(id: buildId) }
        }

        let attrs = response.data.attributes
        print(TerminalUI.bold("Build #\(attrs?.number ?? 0)"))
        print("  Status:     \(attrs?.completionStatus ?? attrs?.executionProgress ?? "Unknown")")
        print("  Started:    \(attrs?.startedDate ?? "N/A")")
        print("  Finished:   \(attrs?.finishedDate ?? "N/A")")
        print("  Reason:     \(attrs?.startReason ?? "N/A")")
        if let commit = attrs?.sourceCommit {
            print("  Commit:     \(commit.commitSha?.prefix(12) ?? "N/A")")
            print("  Message:    \(commit.message ?? "N/A")")
            print("  Author:     \(commit.author?.displayName ?? "N/A")")
        }
        print("")
    }

    private func showBuildErrors(client: APIClient, buildId: String) throws {
        let actionsResponse = try withLoading("Fetching errors...") {
            try runAsync { try await client.listBuildActions(buildRunId: buildId) }
        }

        let failedActions = actionsResponse.data.filter {
            $0.attributes?.completionStatus == "FAILED" ||
            $0.attributes?.completionStatus == "ERRORED"
        }

        var allIssues: [CiIssue] = []
        for action in failedActions {
            let issuesResponse = try runAsync {
                try await client.listIssues(buildActionId: action.id)
            }
            allIssues.append(contentsOf: issuesResponse.data)
        }

        if failedActions.isEmpty && allIssues.isEmpty {
            print("No errors found for this build.")
        } else {
            if !failedActions.isEmpty {
                print(TerminalUI.bold("Failed Actions:"))
                for action in failedActions {
                    print("  \(action.attributes?.name ?? "Unknown") - \(action.attributes?.completionStatus ?? "")")
                }
            }
            if !allIssues.isEmpty {
                print("")
                print(TerminalUI.bold("Issues (\(allIssues.count)):"))
                for issue in allIssues {
                    let issueType = issue.attributes?.issueType ?? "UNKNOWN"
                    let message = issue.attributes?.message ?? "No message"
                    print("  [\(issueType)] \(message)")
                }
            }
        }
        print("")
    }

    private func startBuild(client: APIClient, workflowId: String) throws {
        let response = try withLoading("Starting build...") {
            try runAsync { try await client.startBuildRun(workflowId: workflowId) }
        }

        print("Build started")
        print("  Build ID: \(response.data.id)")
        if let number = response.data.attributes?.number {
            print("  Build number: \(number)")
        }
        print("")
    }

    private func watchBuild(client: APIClient, buildId: String) throws {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateFormatterNoFrac = ISO8601DateFormatter()
        dateFormatterNoFrac.formatOptions = [.withInternetDateTime]

        func parseDate(_ string: String?) -> Date? {
            guard let string else { return nil }
            return dateFormatter.date(from: string) ?? dateFormatterNoFrac.date(from: string)
        }

        func formatDuration(_ seconds: Int) -> String {
            if seconds < 60 { return "\(seconds)s" }
            let m = seconds / 60
            let s = seconds % 60
            return s > 0 ? "\(m)m \(s)s" : "\(m)m"
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

        while true {
            let response = try runAsync {
                try await client.getBuildRun(id: buildId)
            }
            let build = response.data
            let attrs = build.attributes
            let progress = attrs?.executionProgress ?? "UNKNOWN"
            let status = attrs?.completionStatus
            let buildNumber = attrs?.number.map { "#\($0)" } ?? buildId

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

            let actionsResponse = try runAsync {
                try await client.listBuildActions(buildRunId: buildId)
            }
            let actions = actionsResponse.data

            // Clear previous output
            if previousLineCount > 0 {
                for _ in 0..<previousLineCount {
                    TerminalUI.clearLine()
                    TerminalUI.moveCursorUp(1)
                }
                TerminalUI.clearLine()
            }

            if progress == "COMPLETE" {
                let statusText = status ?? "UNKNOWN"
                print("Build \(buildNumber) \(colorStatus(statusText)) (\(elapsed))")
                for action in actions {
                    let name = action.attributes?.name ?? "Unknown"
                    let actionStatus = action.attributes?.completionStatus ?? "-"
                    print("  \(name)  \(colorStatus(actionStatus))")
                }
                print("")
                return
            }

            // Render live status
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

            sleep(10)
        }
    }

    // MARK: - Actions

    private func actionsMenu(client: APIClient, buildId: String) throws {
        let actionsResponse = try withLoading("Fetching actions...") {
            try runAsync { try await client.listBuildActions(buildRunId: buildId) }
        }

        guard !actionsResponse.data.isEmpty else {
            print("No actions found for this build.")
            print("")
            return
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

        let choices = actionsResponse.data.map { action in
            let name = action.attributes?.name ?? "Unknown"
            let type = action.attributes?.actionType ?? ""
            let status = action.attributes?.completionStatus ?? action.attributes?.executionProgress ?? ""
            return Choice(label: "\(name) - \(colorStatus(status))", value: action.id, description: "- \(type)")
        } + [Choice(label: "Back", value: "back")]

        while true {
            let choice: Choice
            do {
                choice = try SelectPrompt.run(prompt: "Select an action:", choices: choices)
            } catch is SelectPromptError {
                return
            }

            guard choice.value != "back" else { return }

            if let action = actionsResponse.data.first(where: { $0.id == choice.value }) {
                try actionDetailMenu(client: client, action: action)
            }
        }
    }

    private func actionDetailMenu(client: APIClient, action: CiBuildAction) throws {
        let actionName = action.attributes?.name ?? "Unknown"
        let isTestAction = action.attributes?.actionType == "TEST"

        while true {
            var menuChoices = [
                Choice(label: "View issues", value: "issues", description: "- Compiler errors & warnings"),
            ]
            if isTestAction {
                menuChoices.append(Choice(label: "View test results", value: "tests"))
            }
            menuChoices.append(Choice(label: "List artifacts", value: "artifacts"))
            menuChoices.append(Choice(label: "Back", value: "back"))

            let choice: Choice
            do {
                choice = try SelectPrompt.run(prompt: "\(actionName) -", choices: menuChoices)
            } catch is SelectPromptError {
                return
            }

            switch choice.value {
            case "issues":
                try showActionIssues(client: client, action: action)
            case "tests":
                try showActionTestResults(client: client, action: action)
            case "artifacts":
                try showActionArtifacts(client: client, action: action)
            default:
                return
            }
        }
    }

    private func showActionIssues(client: APIClient, action: CiBuildAction) throws {
        let actionName = action.attributes?.name ?? "Unknown"

        let response = try withLoading("Fetching issues...") {
            try runAsync { try await client.listIssues(buildActionId: action.id) }
        }

        guard !response.data.isEmpty else {
            print("No issues found for \(actionName).")
            print("")
            return
        }

        let errors = response.data.filter { $0.attributes?.issueType == "ERROR" }
        let warnings = response.data.filter { $0.attributes?.issueType == "WARNING" }
        let others = response.data.filter { $0.attributes?.issueType != "ERROR" && $0.attributes?.issueType != "WARNING" }

        print(TerminalUI.bold("\(actionName) - Issues (\(response.data.count)):"))
        print("")

        if !errors.isEmpty {
            print(TerminalUI.red("  Errors (\(errors.count)):"))
            for issue in errors {
                let message = issue.attributes?.message ?? "No message"
                let file = issue.attributes?.fileSource?.path ?? ""
                let line = issue.attributes?.fileSource?.lineNumber
                if !file.isEmpty {
                    let location = line.map { "\(file):\($0)" } ?? file
                    print("    \(location)")
                }
                print("    \(message)")
                print("")
            }
        }

        if !warnings.isEmpty {
            print(TerminalUI.yellow("  Warnings (\(warnings.count)):"))
            for issue in warnings {
                let message = issue.attributes?.message ?? "No message"
                let file = issue.attributes?.fileSource?.path ?? ""
                let line = issue.attributes?.fileSource?.lineNumber
                if !file.isEmpty {
                    let location = line.map { "\(file):\($0)" } ?? file
                    print("    \(location)")
                }
                print("    \(message)")
                print("")
            }
        }

        if !others.isEmpty {
            for issue in others {
                let issueType = issue.attributes?.issueType ?? "UNKNOWN"
                let message = issue.attributes?.message ?? "No message"
                print("  [\(issueType)] \(message)")
            }
            print("")
        }
    }

    private func showActionTestResults(client: APIClient, action: CiBuildAction) throws {
        let actionName = action.attributes?.name ?? "Unknown"

        let response = try withLoading("Fetching test results...") {
            try runAsync { try await client.listTestResults(buildActionId: action.id) }
        }

        guard !response.data.isEmpty else {
            print("No test results found for \(actionName).")
            print("")
            return
        }

        let passed = response.data.filter { $0.attributes?.status == "SUCCESS" }
        let failed = response.data.filter { $0.attributes?.status == "FAILURE" || $0.attributes?.status == "EXPECTED_FAILURE" }
        let skipped = response.data.filter { $0.attributes?.status == "SKIPPED" }

        print(TerminalUI.bold("\(actionName) - Test Results:"))
        print("  Total: \(response.data.count)  " +
              TerminalUI.green("Passed: \(passed.count)") + "  " +
              TerminalUI.red("Failed: \(failed.count)") + "  " +
              TerminalUI.dim("Skipped: \(skipped.count)"))
        print("")

        if !failed.isEmpty {
            print(TerminalUI.red("  Failures:"))
            for test in failed {
                let className = test.attributes?.className ?? ""
                let testName = test.attributes?.name ?? "Unknown"
                let fullName = className.isEmpty ? testName : "\(className).\(testName)"
                print("    \(fullName)")
                if let message = test.attributes?.message, !message.isEmpty {
                    let lines = message.split(separator: "\n")
                    for line in lines {
                        print("      \(line)")
                    }
                }
                if let fileSource = test.attributes?.fileSource, let path = fileSource.path {
                    let location = fileSource.lineNumber.map { "\(path):\($0)" } ?? path
                    print("      at \(location)")
                }
                print("")
            }
        }

        if !skipped.isEmpty && skipped.count <= 20 {
            print(TerminalUI.dim("  Skipped:"))
            for test in skipped {
                let className = test.attributes?.className ?? ""
                let testName = test.attributes?.name ?? "Unknown"
                let fullName = className.isEmpty ? testName : "\(className).\(testName)"
                print("    \(fullName)")
            }
            print("")
        } else if !skipped.isEmpty {
            print(TerminalUI.dim("  Skipped: \(skipped.count) tests"))
            print("")
        }

        if !passed.isEmpty && passed.count <= 20 {
            print(TerminalUI.green("  Passed:"))
            for test in passed {
                let className = test.attributes?.className ?? ""
                let testName = test.attributes?.name ?? "Unknown"
                let fullName = className.isEmpty ? testName : "\(className).\(testName)"
                print("    \(fullName)")
            }
            print("")
        } else if !passed.isEmpty {
            print(TerminalUI.green("  Passed: \(passed.count) tests"))
            print("")
        }
    }

    private func showActionArtifacts(client: APIClient, action: CiBuildAction) throws {
        let actionName = action.attributes?.name ?? "Unknown"

        let response = try withLoading("Fetching artifacts...") {
            try runAsync { try await client.listArtifacts(buildActionId: action.id) }
        }

        guard !response.data.isEmpty else {
            print("No artifacts found for \(actionName).")
            print("")
            return
        }

        let choices = response.data.map { artifact in
            let name = artifact.attributes?.fileName ?? "Unknown"
            let size = artifact.attributes?.fileSize.map { formatSize($0) } ?? ""
            let type = artifact.attributes?.fileType ?? ""
            return Choice(label: name, value: artifact.id, description: "- \(type) \(size)")
        } + [Choice(label: "Back", value: "back")]

        let choice: Choice
        do {
            choice = try SelectPrompt.run(prompt: "\(actionName) - Artifacts:", choices: choices)
        } catch is SelectPromptError {
            return
        }

        guard choice.value != "back" else { return }

        if let artifact = response.data.first(where: { $0.id == choice.value }),
           let urlString = artifact.attributes?.downloadUrl,
           let url = URL(string: urlString) {
            let fileName = artifact.attributes?.fileName ?? "artifact"
            let dest = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(fileName)

            try withLoading("Downloading \(fileName)...") {
                try runAsync { try await client.downloadArtifact(url: url, to: dest) }
            }

            print("Downloaded: \(dest.path)")
            print("")
        }
    }

    // MARK: - Logs

    private func downloadLogs(client: APIClient, buildId: String) throws {
        let actionsResponse = try withLoading("Fetching logs...") {
            try runAsync { try await client.listBuildActions(buildRunId: buildId) }
        }

        var logArtifacts: [(action: CiBuildAction, artifact: CiArtifact)] = []
        for action in actionsResponse.data {
            let artifactsResponse = try runAsync {
                try await client.listArtifacts(buildActionId: action.id)
            }
            let logs = artifactsResponse.data.filter { $0.attributes?.fileType == "LOG_BUNDLE" }
            for artifact in logs {
                logArtifacts.append((action: action, artifact: artifact))
            }
        }

        guard !logArtifacts.isEmpty else {
            print("No logs found for this build.")
            print("")
            return
        }

        let choices = logArtifacts.map { entry in
            let actionName = entry.action.attributes?.name ?? "Unknown"
            let fileName = entry.artifact.attributes?.fileName ?? "Unknown"
            let size = entry.artifact.attributes?.fileSize.map { formatSize($0) } ?? ""
            return Choice(label: "\(actionName) - \(fileName)", value: entry.artifact.id, description: "- \(size)")
        } + [Choice(label: "Download all", value: "all"),
             Choice(label: "Back", value: "back")]

        let choice: Choice
        do {
            choice = try SelectPrompt.run(prompt: "Select a log to download:", choices: choices)
        } catch is SelectPromptError {
            return
        }

        guard choice.value != "back" else { return }

        let toDownload: [(action: CiBuildAction, artifact: CiArtifact)]
        if choice.value == "all" {
            toDownload = logArtifacts
        } else {
            toDownload = logArtifacts.filter { $0.artifact.id == choice.value }
        }

        for entry in toDownload {
            guard let urlString = entry.artifact.attributes?.downloadUrl,
                  let url = URL(string: urlString) else { continue }

            let fileName = entry.artifact.attributes?.fileName ?? "artifact"
            let dest = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(fileName)

            try withLoading("Downloading \(fileName)...") {
                try runAsync { try await client.downloadArtifact(url: url, to: dest) }
            }

            print("Downloaded: \(dest.path)")
        }
        print("")
    }

    // MARK: - Artifacts

    private func artifactsMenu(client: APIClient, buildId: String) throws {
        let actionsResponse = try withLoading("Fetching artifacts...") {
            try runAsync { try await client.listBuildActions(buildRunId: buildId) }
        }

        var allArtifacts: [CiArtifact] = []
        for action in actionsResponse.data {
            let artifactsResponse = try runAsync {
                try await client.listArtifacts(buildActionId: action.id)
            }
            allArtifacts.append(contentsOf: artifactsResponse.data)
        }

        guard !allArtifacts.isEmpty else {
            print("No artifacts found.")
            print("")
            return
        }

        let choices = allArtifacts.map { artifact in
            let name = artifact.attributes?.fileName ?? "Unknown"
            let size = artifact.attributes?.fileSize.map { formatSize($0) } ?? ""
            let type = artifact.attributes?.fileType ?? ""
            return Choice(label: name, value: artifact.id, description: "- \(type) \(size)")
        } + [Choice(label: "Back", value: "back")]

        let choice: Choice
        do {
            choice = try SelectPrompt.run(prompt: "Select an artifact:", choices: choices)
        } catch is SelectPromptError {
            return
        }

        guard choice.value != "back" else { return }

        if let artifact = allArtifacts.first(where: { $0.id == choice.value }),
           let urlString = artifact.attributes?.downloadUrl,
           let url = URL(string: urlString) {
            let fileName = artifact.attributes?.fileName ?? "artifact"
            let dest = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(fileName)

            try withLoading("Downloading \(fileName)...") {
                try runAsync { try await client.downloadArtifact(url: url, to: dest) }
            }

            print("Downloaded: \(dest.path)")
            print("")
        }
    }

    // MARK: - Helpers

    private func formatSize(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return "\(bytes / 1024) KB" }
        return "\(bytes / 1024 / 1024) MB"
    }
}

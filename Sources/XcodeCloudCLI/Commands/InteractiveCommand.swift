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

        print(TerminalUI.bold("Xcode Cloud CLI") + " " + TerminalUI.dim("v1.0.0"))
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

        let choices = response.data.map { product in
            let name = product.attributes?.name ?? "Unknown"
            let type = product.attributes?.productType ?? ""
            return Choice(label: name, value: product.id, description: "- \(type)")
        } + [Choice(label: "Back", value: "back")]

        while true {
            let choice: Choice
            do {
                choice = try SelectPrompt.run(prompt: "Select a product:", choices: choices)
            } catch is SelectPromptError {
                return
            }

            guard choice.value != "back" else { return }

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

        let choices = response.data.map { workflow in
            let name = workflow.attributes?.name ?? "Unknown"
            let enabled = workflow.attributes?.isEnabled == true ? "" : " (disabled)"
            return Choice(label: name, value: workflow.id, description: enabled.isEmpty ? nil : enabled)
        } + [Choice(label: "Back", value: "back")]

        while true {
            let choice: Choice
            do {
                choice = try SelectPrompt.run(prompt: "Select a workflow:", choices: choices)
            } catch is SelectPromptError {
                return
            }

            guard choice.value != "back" else { return }

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

        let choices = response.data.map { build in
            let number = build.attributes?.number.map { "#\($0)" } ?? ""
            let status = build.attributes?.completionStatus ?? build.attributes?.executionProgress ?? "Unknown"
            let commit = build.attributes?.sourceCommit?.message?.prefix(40) ?? ""
            let label = "\(number) \(status)"
            let desc = commit.isEmpty ? nil : "- \(commit)"
            return Choice(label: label, value: build.id, description: desc)
        } + [Choice(label: "Back", value: "back")]

        while true {
            let choice: Choice
            do {
                choice = try SelectPrompt.run(prompt: "Select a build:", choices: choices)
            } catch is SelectPromptError {
                return
            }

            guard choice.value != "back" else { return }

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
                        Choice(label: "View details", value: "details"),
                        Choice(label: "Show errors", value: "errors"),
                        Choice(label: "List artifacts", value: "artifacts"),
                        Choice(label: "Back", value: "back"),
                    ]
                )
            } catch is SelectPromptError {
                return
            }

            switch choice.value {
            case "details":
                try showBuildDetails(client: client, buildId: buildId)
            case "errors":
                try showBuildErrors(client: client, buildId: buildId)
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

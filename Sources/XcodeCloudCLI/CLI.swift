import ArgumentParser
import Foundation

public struct XcodeCloud: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "xcodecloud",
        abstract: "A command-line interface for Xcode Cloud",
        discussion: """
            Interact with Xcode Cloud via the App Store Connect API.

            INTERACTIVE MODE
              Run 'xcodecloud' with no arguments to launch interactive mode.
              Navigate with arrow keys, select with Enter, quit with 'q'.

            AUTHENTICATION
              Credentials can be provided via:
              1. Command-line flags (--key-id, --issuer-id, --private-key-path)
              2. Environment variables (XCODE_CLOUD_KEY_ID, XCODE_CLOUD_ISSUER_ID,
                 XCODE_CLOUD_PRIVATE_KEY_PATH)
              3. Global config (~/.xcodecloud/config.json)
              4. Project-local config (.xcodecloud/config.json)

              Run 'xcodecloud auth init' to set up credentials interactively.

            EXAMPLES
              Launch interactive mode:
                $ xcodecloud

              List all CI products:
                $ xcodecloud products list

              List workflows for a product:
                $ xcodecloud workflows list <product-id>

              Start a build:
                $ xcodecloud builds start <workflow-id>

              Get build status with table output:
                $ xcodecloud builds get <build-id> -o table

            DOCUMENTATION
              https://github.com/yapstudios/xcodecloud-cli
              https://raw.githubusercontent.com/yapstudios/xcodecloud-cli/main/README.md
            """,
        version: "1.1.1",
        subcommands: [
            InteractiveCommand.self,
            AuthCommand.self,
            ProductsCommand.self,
            WorkflowsCommand.self,
            BuildsCommand.self,
            ArtifactsCommand.self
        ],
        defaultSubcommand: InteractiveCommand.self
    )

    public init() {}
}

/// Prints to stderr
func printError(_ message: String) {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
}

/// Prints verbose output if enabled
func printVerbose(_ message: String, verbose: Bool) {
    guard verbose else { return }
    FileHandle.standardError.write(Data("[\(message)]\n".utf8))
}

/// Sends a macOS notification via osascript
func sendNotification(title: String, message: String) {
    let script = "display notification \"\(message)\" with title \"\(title)\""
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", script]
    try? process.run()
}

/// Runs an async closure synchronously
func runAsync<T: Sendable>(_ block: @Sendable @escaping () async throws -> T) throws -> T {
    let semaphore = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var result: Result<T, Error>?

    Task {
        do {
            result = .success(try await block())
        } catch {
            result = .failure(error)
        }
        semaphore.signal()
    }

    semaphore.wait()

    switch result! {
    case .success(let value):
        return value
    case .failure(let error):
        throw error
    }
}

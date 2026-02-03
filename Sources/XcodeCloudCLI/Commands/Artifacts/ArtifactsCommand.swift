import ArgumentParser
import Foundation
import XcodeCloudKit

struct ArtifactsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "artifacts",
        abstract: "Manage build artifacts",
        discussion: """
            Artifacts are files produced by build actions, such as app archives,
            test results, and logs.

            ARTIFACT TYPES
              ARCHIVE - App archive (.xcarchive)
              PRODUCT_LOG - Build log
              XCODE_LOG - Xcode log
              TEST_PRODUCTS - Test results
              TEST_RESULTS - Test report

            WORKFLOW
              To download artifacts, first get the build action IDs:
                $ xcodecloud builds actions <build-id>

              Then list artifacts for a specific action:
                $ xcodecloud artifacts list <build-action-id>

              Finally, download the artifact:
                $ xcodecloud artifacts download <artifact-id>

            EXAMPLES
              List artifacts for a build action:
                $ xcodecloud artifacts list <build-action-id>

              Download an artifact:
                $ xcodecloud artifacts download <artifact-id>

              Download to a specific location:
                $ xcodecloud artifacts download <artifact-id> --dir ./downloads/
            """,
        subcommands: [
            ArtifactsListCommand.self,
            ArtifactsDownloadCommand.self
        ]
    )
}

struct ArtifactsListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List artifacts for a build action"
    )

    @OptionGroup var options: GlobalOptions

    @Argument(help: "Build action ID")
    var buildActionId: String

    mutating func run() throws {
        let client: APIClient
        do {
            client = try options.apiClient()
        } catch let error as CLIError {
            printError(error.localizedDescription)
            throw ExitCode(rawValue: error.exitCode)
        }

        let actionId = buildActionId
        let verbose = options.verbose

        do {
            printVerbose("Fetching artifacts for action \(actionId)...", verbose: verbose)
            let response = try runAsync {
                try await client.listArtifacts(buildActionId: actionId)
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

struct ArtifactsDownloadCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "download",
        abstract: "Download an artifact"
    )

    @OptionGroup var options: GlobalOptions

    @Argument(help: "Artifact ID")
    var artifactId: String

    @Option(name: [.customShort("d"), .customLong("dir")], help: "Output directory (default: current directory)")
    var outputDir: String = "."

    mutating func run() throws {
        let client: APIClient
        do {
            client = try options.apiClient()
        } catch let error as CLIError {
            printError(error.localizedDescription)
            throw ExitCode(rawValue: error.exitCode)
        }

        let artId = artifactId
        let outDir = outputDir
        let verbose = options.verbose
        let quiet = options.quiet

        do {
            printVerbose("Fetching artifact info \(artId)...", verbose: verbose)
            let response = try runAsync {
                try await client.getArtifact(id: artId)
            }

            guard let downloadUrl = response.data.attributes?.downloadUrl,
                  let url = URL(string: downloadUrl) else {
                printError("Artifact has no download URL")
                throw ExitCode.failure
            }

            let fileName = response.data.attributes?.fileName ?? "\(artId).zip"
            let expandedOutputDir = (outDir as NSString).expandingTildeInPath
            let destinationURL = URL(fileURLWithPath: expandedOutputDir).appendingPathComponent(fileName)

            // Create output directory if needed
            try FileManager.default.createDirectory(
                at: URL(fileURLWithPath: expandedOutputDir),
                withIntermediateDirectories: true
            )

            if !quiet {
                print("Downloading \(fileName)...")
                if let size = response.data.attributes?.fileSize {
                    print("  Size: \(formatFileSize(size))")
                }
            }

            printVerbose("Downloading from \(downloadUrl)...", verbose: verbose)
            try runAsync {
                try await client.downloadArtifact(url: url, to: destinationURL)
            }

            if !quiet {
                print("Downloaded to \(destinationURL.path)")
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

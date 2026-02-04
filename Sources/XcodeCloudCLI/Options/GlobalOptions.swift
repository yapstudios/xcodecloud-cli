import ArgumentParser
import XcodeCloudKit

/// Global options available to all commands
struct GlobalOptions: ParsableArguments {
    @Option(name: .long, help: "Use named auth profile")
    var profile: String?

    @Option(name: .long, help: "API Key ID")
    var keyId: String?

    @Option(name: .long, help: "Issuer ID")
    var issuerId: String?

    @Option(name: .long, help: "Path to .p8 private key file")
    var privateKeyPath: String?

    @Option(name: .long, help: "Private key content (base64 encoded)")
    var privateKey: String?

    @Option(name: [.customShort("o"), .long], help: "Output format: json, table, csv")
    var output: OutputFormat = .json

    @Flag(name: .long, help: "Pretty-print JSON output")
    var pretty: Bool = false

    @Flag(name: .long, help: "Disable colored output")
    var noColor: Bool = false

    @Flag(name: [.customShort("v"), .customLong("verbose")], help: "Enable verbose output")
    var verbose: Bool = false

    @Flag(name: [.customShort("q"), .long], help: "Suppress non-essential output")
    var quiet: Bool = false

    /// Creates credential options from the global options
    func credentialOptions() -> CredentialOptions {
        CredentialOptions(
            keyId: keyId,
            issuerId: issuerId,
            privateKeyPath: privateKeyPath,
            privateKey: privateKey,
            profile: profile
        )
    }

    /// Creates an output formatter from the global options
    func outputFormatter() -> OutputFormatter {
        OutputFormatter(format: output, prettyPrint: pretty, noColor: noColor)
    }

    /// Resolves credentials and creates an API client
    func apiClient() throws -> APIClient {
        let resolver = CredentialResolver()
        let credentials = try resolver.resolve(options: credentialOptions())
        return APIClient(credentials: credentials)
    }

    /// Creates an API client for a specific profile name
    func apiClient(profile: String) throws -> APIClient {
        var opts = credentialOptions()
        opts.profile = profile
        let resolver = CredentialResolver()
        let credentials = try resolver.resolve(options: opts)
        return APIClient(credentials: credentials)
    }
}

extension OutputFormat: ExpressibleByArgument {}

import ArgumentParser
import Foundation
import XcodeCloudKit

struct AuthCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "auth",
        abstract: "Manage authentication credentials",
        discussion: """
            Set up and manage App Store Connect API credentials.

            Credentials are stored in ~/.xcodecloud/config.json with restricted permissions (600).
            You can configure multiple profiles for different accounts or teams.

            CONFIG FILE FORMAT
              {
                "keyId": "ABC123DEF4",
                "issuerId": "12345678-1234-1234-1234-123456789abc",
                "privateKeyPath": "~/AuthKey_ABC123DEF4.p8"
              }

            GETTING API KEYS
              You need a Team key (not an Individual key) with CI access.

              1. Go to App Store Connect > Users and Access > Integrations > App Store Connect API
              2. Click "Generate API Key" under Team Keys
              3. Give it a name and select Admin, App Manager, or Developer role
              4. Download the .p8 file (you can only download it once!)
              5. Note the Key ID and Issuer ID shown on the page

            EXAMPLES
              Set up credentials interactively:
                $ xcodecloud auth init

              Verify credentials work:
                $ xcodecloud auth check

              List configured profiles:
                $ xcodecloud auth profiles
            """,
        subcommands: [
            AuthInitCommand.self,
            AuthCheckCommand.self,
            AuthProfilesCommand.self,
            AuthUseCommand.self
        ]
    )
}

struct AuthInitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Set up credentials interactively"
    )

    @Option(name: .long, help: "Profile name (default: 'default')")
    var profile: String = "default"

    @Flag(name: .long, help: "Overwrite existing profile")
    var force: Bool = false

    mutating func run() throws {
        let resolver = CredentialResolver()
        let configPath = CredentialResolver.globalConfigPath
        var config = try resolver.loadConfig(from: configPath) ?? ConfigFile()

        // Check if profile exists
        if config.profiles[profile] != nil && !force {
            print("Profile '\(profile)' already exists. Use --force to overwrite.")
            throw ExitCode.failure
        }

        print("Setting up Xcode Cloud CLI credentials")
        print("=======================================\n")
        print("You'll need an App Store Connect API Team key (not Individual).")
        print("Create one at:")
        print("  https://appstoreconnect.apple.com/access/integrations/api\n")

        // Get Key ID
        print("Key ID (10-character alphanumeric, e.g., ABC123DEF4):")
        print("> ", terminator: "")
        guard let keyId = readLine()?.trimmingCharacters(in: .whitespaces), !keyId.isEmpty else {
            print("Key ID is required")
            throw ExitCode.failure
        }

        // Get Issuer ID
        print("\nIssuer ID (UUID format, e.g., 12345678-1234-1234-1234-123456789abc):")
        print("> ", terminator: "")
        guard let issuerId = readLine()?.trimmingCharacters(in: .whitespaces), !issuerId.isEmpty else {
            print("Issuer ID is required")
            throw ExitCode.failure
        }

        // Get private key path
        print("\nPath to .p8 private key file (e.g., ~/AuthKey_ABC123DEF4.p8):")
        print("> ", terminator: "")
        guard let keyPath = readLine()?.trimmingCharacters(in: .whitespaces), !keyPath.isEmpty else {
            print("Private key path is required")
            throw ExitCode.failure
        }

        // Verify the key file exists
        let expandedPath = (keyPath as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            print("Error: File not found at \(keyPath)")
            throw ExitCode.failure
        }

        // Create and save profile
        let newProfile = Profile(keyId: keyId, issuerId: issuerId, privateKeyPath: keyPath)
        config.profiles[profile] = newProfile

        // Set as default if it's the first profile or named 'default'
        if config.defaultProfile == nil || profile == "default" {
            config.defaultProfile = profile
        }

        try resolver.saveConfig(config, to: configPath)

        print("\nCredentials saved to \(configPath)")
        print("  Profile: \(profile)")

        if config.defaultProfile == profile {
            print("  (set as default)")
        }

        print("\nRun 'xcodecloud auth check' to verify your credentials work.")
    }
}

struct AuthCheckCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "check",
        abstract: "Verify credentials are valid"
    )

    @OptionGroup var options: GlobalOptions

    mutating func run() throws {
        let verbose = options.verbose
        printVerbose("Resolving credentials...", verbose: verbose)

        let client: APIClient
        do {
            client = try options.apiClient()
        } catch let error as CLIError {
            printError(error.localizedDescription)
            throw ExitCode(rawValue: error.exitCode)
        }

        printVerbose("Making test API call...", verbose: verbose)

        do {
            let response = try runAsync {
                try await client.listProducts(limit: 1)
            }
            print("Credentials are valid")
            print("  Found \(response.data.count) CI product(s)")

            if let first = response.data.first {
                print("  Example: \(first.attributes?.name ?? first.id)")
            }
        } catch let error as CLIError {
            printError(error.localizedDescription)
            throw ExitCode(rawValue: error.exitCode)
        }
    }
}

struct AuthProfilesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "profiles",
        abstract: "List configured profiles"
    )

    mutating func run() throws {
        let resolver = CredentialResolver()

        // Check global config
        if let config = try resolver.loadConfig(from: CredentialResolver.globalConfigPath) {
            print("Global config (~/.xcodecloud/config.json):")
            print("  Default: \(config.defaultProfile ?? "(none)")")
            print("  Profiles:")
            for (name, profile) in config.profiles.sorted(by: { $0.key < $1.key }) {
                let marker = name == config.defaultProfile ? " *" : ""
                print("    - \(name)\(marker)")
                print("      Key ID: \(profile.keyId)")
                print("      Issuer ID: \(profile.issuerId)")
            }
        } else {
            print("No global config found at ~/.xcodecloud/config.json")
        }

        // Check local config
        if let config = try resolver.loadConfig(from: CredentialResolver.localConfigPath) {
            print("\nLocal config (.xcodecloud/config.json):")
            print("  Default: \(config.defaultProfile ?? "(none)")")
            print("  Profiles:")
            for (name, profile) in config.profiles.sorted(by: { $0.key < $1.key }) {
                let marker = name == config.defaultProfile ? " *" : ""
                print("    - \(name)\(marker)")
                print("      Key ID: \(profile.keyId)")
            }
        }
    }
}

struct AuthUseCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "use",
        abstract: "Set the default profile"
    )

    @Argument(help: "Profile name to set as default")
    var profile: String

    @Flag(name: .long, help: "Update local config instead of global")
    var local: Bool = false

    mutating func run() throws {
        let resolver = CredentialResolver()
        let configPath = local ? CredentialResolver.localConfigPath : CredentialResolver.globalConfigPath

        guard var config = try resolver.loadConfig(from: configPath) else {
            print("No config file found at \(configPath)")
            throw ExitCode.failure
        }

        guard config.profiles[profile] != nil else {
            print("Profile '\(profile)' not found")
            print("Available profiles: \(config.profiles.keys.sorted().joined(separator: ", "))")
            throw ExitCode.failure
        }

        config.defaultProfile = profile
        try resolver.saveConfig(config, to: configPath)

        print("Default profile set to '\(profile)'")
    }
}

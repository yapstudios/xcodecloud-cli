import Foundation

/// Options for resolving credentials from various sources
public struct CredentialOptions: Sendable {
    public var keyId: String?
    public var issuerId: String?
    public var privateKeyPath: String?
    public var privateKey: String?
    public var profile: String?

    public init(
        keyId: String? = nil,
        issuerId: String? = nil,
        privateKeyPath: String? = nil,
        privateKey: String? = nil,
        profile: String? = nil
    ) {
        self.keyId = keyId
        self.issuerId = issuerId
        self.privateKeyPath = privateKeyPath
        self.privateKey = privateKey
        self.profile = profile
    }
}

/// Resolves credentials from multiple sources in priority order:
/// 1. Command-line options
/// 2. Environment variables
/// 3. Local config file (.xcodecloud/config.json)
/// 4. Global config file (~/.xcodecloud/config.json)
public struct CredentialResolver: Sendable {
    public static let globalConfigPath = "~/.xcodecloud/config.json"
    public static let localConfigPath = ".xcodecloud/config.json"

    public static let envKeyId = "XCODE_CLOUD_KEY_ID"
    public static let envIssuerId = "XCODE_CLOUD_ISSUER_ID"
    public static let envPrivateKeyPath = "XCODE_CLOUD_PRIVATE_KEY_PATH"
    public static let envPrivateKey = "XCODE_CLOUD_PRIVATE_KEY"

    public init() {}

    /// Resolves credentials from all available sources
    public func resolve(options: CredentialOptions = CredentialOptions()) throws -> Credentials {
        // Try command-line options first
        if let creds = try resolveFromOptions(options) {
            return creds
        }

        // Try environment variables
        if let creds = try resolveFromEnvironment() {
            return creds
        }

        // Try profile from options or config
        let profileName = options.profile

        // Try local config
        if let creds = try resolveFromConfig(Self.localConfigPath, profileName: profileName) {
            return creds
        }

        // Try global config
        if let creds = try resolveFromConfig(Self.globalConfigPath, profileName: profileName) {
            return creds
        }

        throw CLIError.missingCredentials(
            """
            No credentials configured.

            Run 'xcodecloud auth init' to set up credentials interactively.

            Credentials can also be provided via:
              - Command-line flags (--key-id, --issuer-id, --private-key-path or --private-key)
              - Environment variables (XCODE_CLOUD_KEY_ID, XCODE_CLOUD_ISSUER_ID,
                XCODE_CLOUD_PRIVATE_KEY_PATH or XCODE_CLOUD_PRIVATE_KEY)
              - Config file (~/.xcodecloud/config.json)
            """
        )
    }

    private func resolveFromOptions(_ options: CredentialOptions) throws -> Credentials? {
        guard let keyId = options.keyId,
              let issuerId = options.issuerId else {
            return nil
        }

        if let key = options.privateKey {
            // Decode base64 if needed
            let decodedKey: String
            if let data = Data(base64Encoded: key), let decoded = String(data: data, encoding: .utf8) {
                decodedKey = decoded
            } else {
                decodedKey = key
            }
            return Credentials(keyId: keyId, issuerId: issuerId, privateKey: decodedKey)
        } else if let path = options.privateKeyPath {
            return try Credentials(keyId: keyId, issuerId: issuerId, privateKeyPath: path)
        }

        return nil
    }

    private func resolveFromEnvironment() throws -> Credentials? {
        guard let keyId = ProcessInfo.processInfo.environment[Self.envKeyId],
              let issuerId = ProcessInfo.processInfo.environment[Self.envIssuerId] else {
            return nil
        }

        if let key = ProcessInfo.processInfo.environment[Self.envPrivateKey] {
            // Decode base64
            if let data = Data(base64Encoded: key), let decoded = String(data: data, encoding: .utf8) {
                return Credentials(keyId: keyId, issuerId: issuerId, privateKey: decoded)
            }
            return Credentials(keyId: keyId, issuerId: issuerId, privateKey: key)
        } else if let path = ProcessInfo.processInfo.environment[Self.envPrivateKeyPath] {
            return try Credentials(keyId: keyId, issuerId: issuerId, privateKeyPath: path)
        }

        return nil
    }

    private func resolveFromConfig(_ path: String, profileName: String?) throws -> Credentials? {
        let expandedPath = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            return nil
        }

        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: expandedPath))
        } catch {
            throw CLIError.configFileError("Could not read \(path): \(error.localizedDescription)")
        }

        let config: ConfigFile
        do {
            config = try JSONDecoder().decode(ConfigFile.self, from: data)
        } catch {
            throw CLIError.configFileError("Invalid JSON in \(path): \(error.localizedDescription)")
        }

        let targetProfile = profileName ?? config.defaultProfile
        guard let name = targetProfile, let profile = config.profiles[name] else {
            if profileName != nil {
                throw CLIError.configFileError("Profile '\(profileName!)' not found in \(path)")
            }
            return nil
        }

        return try profile.toCredentials()
    }

    /// Loads the config file from a path
    public func loadConfig(from path: String) throws -> ConfigFile? {
        let expandedPath = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            return nil
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: expandedPath))
        return try JSONDecoder().decode(ConfigFile.self, from: data)
    }

    /// Saves a config file to a path
    public func saveConfig(_ config: ConfigFile, to path: String) throws {
        let expandedPath = (path as NSString).expandingTildeInPath
        let dirPath = (expandedPath as NSString).deletingLastPathComponent

        // Create directory if needed
        if !FileManager.default.fileExists(atPath: dirPath) {
            try FileManager.default.createDirectory(atPath: dirPath, withIntermediateDirectories: true)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: URL(fileURLWithPath: expandedPath))

        // Set restrictive permissions (owner read/write only)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: expandedPath)
    }
}

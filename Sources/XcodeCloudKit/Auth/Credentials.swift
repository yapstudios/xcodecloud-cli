import Foundation

/// Credentials required for App Store Connect API authentication
public struct Credentials: Codable, Sendable {
    public let keyId: String
    public let issuerId: String
    public let privateKey: String

    public init(keyId: String, issuerId: String, privateKey: String) {
        self.keyId = keyId
        self.issuerId = issuerId
        self.privateKey = privateKey
    }

    /// Creates credentials by reading the private key from a file
    public init(keyId: String, issuerId: String, privateKeyPath: String) throws {
        self.keyId = keyId
        self.issuerId = issuerId

        let expandedPath = (privateKeyPath as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            throw CLIError.fileNotFound(privateKeyPath)
        }

        do {
            self.privateKey = try String(contentsOfFile: expandedPath, encoding: .utf8)
        } catch {
            throw CLIError.invalidPrivateKey("Could not read file: \(error.localizedDescription)")
        }
    }
}

/// A named profile containing credentials
public struct Profile: Codable, Sendable {
    public let keyId: String
    public let issuerId: String
    public let privateKeyPath: String?
    public let privateKey: String?

    public init(keyId: String, issuerId: String, privateKeyPath: String? = nil, privateKey: String? = nil) {
        self.keyId = keyId
        self.issuerId = issuerId
        self.privateKeyPath = privateKeyPath
        self.privateKey = privateKey
    }

    public func toCredentials() throws -> Credentials {
        if let key = privateKey {
            return Credentials(keyId: keyId, issuerId: issuerId, privateKey: key)
        } else if let path = privateKeyPath {
            return try Credentials(keyId: keyId, issuerId: issuerId, privateKeyPath: path)
        } else {
            throw CLIError.missingCredentials("No private key or path specified")
        }
    }
}

/// Configuration file structure
public struct ConfigFile: Codable, Sendable {
    public var defaultProfile: String?
    public var profiles: [String: Profile]

    public init(defaultProfile: String? = nil, profiles: [String: Profile] = [:]) {
        self.defaultProfile = defaultProfile
        self.profiles = profiles
    }

    private enum CodingKeys: String, CodingKey {
        case defaultProfile = "default"
        case profiles
    }
}

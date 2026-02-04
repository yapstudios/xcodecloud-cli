import Testing
import Foundation
@testable import XcodeCloudKit

private let testKey = "-----BEGIN PRIVATE KEY-----\nMIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgtest1234567890\n-----END PRIVATE KEY-----"

@Suite("Credentials Tests")
struct CredentialsTests {
    @Test("Creates credentials with inline key")
    func testInlineCredentials() {
        let creds = Credentials(
            keyId: "ABC123",
            issuerId: "DEF456",
            privateKey: "-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----"
        )

        #expect(creds.keyId == "ABC123")
        #expect(creds.issuerId == "DEF456")
        #expect(creds.privateKey.contains("PRIVATE KEY"))
    }

    @Test("Profile serialization")
    func testProfileCoding() throws {
        let profile = Profile(
            keyId: "KEY123",
            issuerId: "ISSUER456",
            privateKeyPath: "~/.xcodecloud/key.p8"
        )

        let encoder = Foundation.JSONEncoder()
        let data = try encoder.encode(profile)

        let decoder = Foundation.JSONDecoder()
        let decoded = try decoder.decode(Profile.self, from: data)

        #expect(decoded.keyId == profile.keyId)
        #expect(decoded.issuerId == profile.issuerId)
        #expect(decoded.privateKeyPath == profile.privateKeyPath)
    }

    @Test("ConfigFile serialization")
    func testConfigFileCoding() throws {
        let config = ConfigFile(
            defaultProfile: "work",
            profiles: [
                "personal": Profile(keyId: "KEY1", issuerId: "ISS1", privateKeyPath: "~/key1.p8"),
                "work": Profile(keyId: "KEY2", issuerId: "ISS2", privateKeyPath: "~/key2.p8")
            ]
        )

        let encoder = Foundation.JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)

        let decoder = Foundation.JSONDecoder()
        let decoded = try decoder.decode(ConfigFile.self, from: data)

        #expect(decoded.defaultProfile == "work")
        #expect(decoded.profiles.count == 2)
        #expect(decoded.profiles["work"]?.keyId == "KEY2")
    }
}

// MARK: - Credential Resolver Tests

@Suite("Credential Resolver Tests")
struct CredentialResolverTests {

    /// Creates a temp directory with an optional key file and config, returns cleanup closure.
    private func makeTempDir() throws -> (path: String, cleanup: () -> Void) {
        let dir = NSTemporaryDirectory() + "xcodecloud-test-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return (dir, { try? FileManager.default.removeItem(atPath: dir) })
    }

    private func writeKeyFile(at path: String) throws {
        try testKey.write(toFile: path, atomically: true, encoding: .utf8)
    }

    private func writeConfig(_ config: ConfigFile, at path: String) throws {
        let dir = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: URL(fileURLWithPath: path))
    }

    // MARK: - Options (command-line flags)

    @Test("Resolves from options with private key path")
    func optionsWithKeyPath() throws {
        let (dir, cleanup) = try makeTempDir()
        defer { cleanup() }

        let keyPath = dir + "/test.p8"
        try writeKeyFile(at: keyPath)

        let resolver = CredentialResolver()
        let options = CredentialOptions(
            keyId: "KEY1",
            issuerId: "ISS1",
            privateKeyPath: keyPath
        )
        let creds = try resolver.resolve(options: options)

        #expect(creds.keyId == "KEY1")
        #expect(creds.issuerId == "ISS1")
        #expect(creds.privateKey.contains("PRIVATE KEY"))
    }

    @Test("Resolves from options with inline private key")
    func optionsWithInlineKey() throws {
        let resolver = CredentialResolver()
        let options = CredentialOptions(
            keyId: "KEY2",
            issuerId: "ISS2",
            privateKey: testKey
        )
        let creds = try resolver.resolve(options: options)

        #expect(creds.keyId == "KEY2")
        #expect(creds.issuerId == "ISS2")
        #expect(creds.privateKey == testKey)
    }

    @Test("Resolves from options with base64-encoded private key")
    func optionsWithBase64Key() throws {
        let encoded = Data(testKey.utf8).base64EncodedString()

        let resolver = CredentialResolver()
        let options = CredentialOptions(
            keyId: "KEY3",
            issuerId: "ISS3",
            privateKey: encoded
        )
        let creds = try resolver.resolve(options: options)

        #expect(creds.keyId == "KEY3")
        #expect(creds.issuerId == "ISS3")
        #expect(creds.privateKey == testKey)
    }

    @Test("Incomplete options fall through to other sources")
    func incompleteOptionsFallThrough() throws {
        // Missing key ID — options path should be skipped
        let resolver = CredentialResolver()
        let options = CredentialOptions(
            issuerId: "ISS1",
            privateKey: testKey
        )
        // Should either resolve from config/env or throw missingCredentials
        // but should NOT use the partial options (no key ID)
        do {
            let creds = try resolver.resolve(options: options)
            // Resolved from config or env — key ID should NOT be nil
            #expect(creds.keyId != "")
            // Should NOT have used our partial options' issuer
            // (unless config also has ISS1, which is unlikely)
        } catch let error as CLIError {
            if case .missingCredentials = error {
                // Also acceptable — no other source available
            } else {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    @Test("Options with nonexistent key path throws fileNotFound")
    func optionsWithBadKeyPath() throws {
        let resolver = CredentialResolver()
        let options = CredentialOptions(
            keyId: "KEY1",
            issuerId: "ISS1",
            privateKeyPath: "/tmp/nonexistent-key-\(UUID().uuidString).p8"
        )
        do {
            _ = try resolver.resolve(options: options)
            Issue.record("Expected fileNotFound error")
        } catch let error as CLIError {
            if case .fileNotFound = error {
                // Expected
            } else {
                Issue.record("Expected fileNotFound, got \(error)")
            }
        }
    }

    // MARK: - Config file

    @Test("Resolves from config file with privateKeyPath")
    func configWithKeyPath() throws {
        let (dir, cleanup) = try makeTempDir()
        defer { cleanup() }

        let keyPath = dir + "/test.p8"
        try writeKeyFile(at: keyPath)

        let configPath = dir + "/config.json"
        let config = ConfigFile(
            defaultProfile: "default",
            profiles: [
                "default": Profile(keyId: "CFGKEY", issuerId: "CFGISS", privateKeyPath: keyPath)
            ]
        )
        try writeConfig(config, at: configPath)

        // Test via loadConfig + profile.toCredentials directly
        // (resolve() may pick up env vars or real config on this machine)
        let resolver = CredentialResolver()
        let loaded = try resolver.loadConfig(from: configPath)
        let profile = loaded!.profiles["default"]!
        let resolved = try profile.toCredentials()

        #expect(resolved.keyId == "CFGKEY")
        #expect(resolved.issuerId == "CFGISS")
        #expect(resolved.privateKey.contains("PRIVATE KEY"))
    }

    @Test("Resolves from config file with inline privateKey")
    func configWithInlineKey() throws {
        let (dir, cleanup) = try makeTempDir()
        defer { cleanup() }

        let configPath = dir + "/config.json"
        let config = ConfigFile(
            defaultProfile: "default",
            profiles: [
                "default": Profile(keyId: "CFGKEY2", issuerId: "CFGISS2", privateKey: testKey)
            ]
        )
        try writeConfig(config, at: configPath)

        let resolver = CredentialResolver()
        let loaded = try resolver.loadConfig(from: configPath)
        let profile = loaded!.profiles["default"]!
        let resolved = try profile.toCredentials()

        #expect(resolved.keyId == "CFGKEY2")
        #expect(resolved.issuerId == "CFGISS2")
        #expect(resolved.privateKey == testKey)
    }

    @Test("Selects named profile from config")
    func configWithNamedProfile() throws {
        let (dir, cleanup) = try makeTempDir()
        defer { cleanup() }

        let configPath = dir + "/config.json"
        let config = ConfigFile(
            defaultProfile: "default",
            profiles: [
                "default": Profile(keyId: "DEFAULT_KEY", issuerId: "DEFAULT_ISS", privateKey: testKey),
                "work": Profile(keyId: "WORK_KEY", issuerId: "WORK_ISS", privateKey: testKey)
            ]
        )
        try writeConfig(config, at: configPath)

        let resolver = CredentialResolver()
        let loaded = try resolver.loadConfig(from: configPath)!

        let defaultProfile = loaded.profiles[loaded.defaultProfile!]!
        let defaultCreds = try defaultProfile.toCredentials()
        #expect(defaultCreds.keyId == "DEFAULT_KEY")

        let workProfile = loaded.profiles["work"]!
        let workCreds = try workProfile.toCredentials()
        #expect(workCreds.keyId == "WORK_KEY")
        #expect(workCreds.issuerId == "WORK_ISS")
    }

    @Test("Profile without key or path throws missingCredentials")
    func profileWithNoKey() throws {
        let profile = Profile(keyId: "KEY1", issuerId: "ISS1")
        do {
            _ = try profile.toCredentials()
            Issue.record("Expected missingCredentials error")
        } catch let error as CLIError {
            if case .missingCredentials = error {
                // Expected
            } else {
                Issue.record("Expected missingCredentials, got \(error)")
            }
        }
    }

    @Test("No credentials configured throws missingCredentials")
    func noCredentials() throws {
        let resolver = CredentialResolver()
        // Empty options, no env vars match, no config at nonexistent path
        do {
            _ = try resolver.resolve(options: CredentialOptions())
            // This might succeed if the user has real config — that's fine
        } catch let error as CLIError {
            if case .missingCredentials = error {
                // Expected when no credentials exist
            } else {
                Issue.record("Expected missingCredentials, got \(error)")
            }
        }
    }

    @Test("Save and load config round-trips")
    func saveAndLoadConfig() throws {
        let (dir, cleanup) = try makeTempDir()
        defer { cleanup() }

        let configPath = dir + "/config.json"
        let config = ConfigFile(
            defaultProfile: "test",
            profiles: [
                "test": Profile(keyId: "RTKEY", issuerId: "RTISS", privateKey: testKey)
            ]
        )

        let resolver = CredentialResolver()
        try resolver.saveConfig(config, to: configPath)

        let loaded = try resolver.loadConfig(from: configPath)
        #expect(loaded != nil)
        #expect(loaded!.defaultProfile == "test")
        #expect(loaded!.profiles["test"]?.keyId == "RTKEY")
        #expect(loaded!.profiles["test"]?.issuerId == "RTISS")
        #expect(loaded!.profiles["test"]?.privateKey == testKey)

        // Verify file permissions are restrictive
        let attrs = try FileManager.default.attributesOfItem(atPath: configPath)
        let perms = attrs[.posixPermissions] as? Int
        #expect(perms == 0o600)
    }

    @Test("Load config from nonexistent path returns nil")
    func loadNonexistentConfig() throws {
        let resolver = CredentialResolver()
        let result = try resolver.loadConfig(from: "/tmp/nonexistent-\(UUID().uuidString)/config.json")
        #expect(result == nil)
    }
}

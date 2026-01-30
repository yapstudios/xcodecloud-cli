import Testing
@testable import XcodeCloudKit

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

        let encoder = JSONEncoder()
        let data = try encoder.encode(profile)

        let decoder = JSONDecoder()
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

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ConfigFile.self, from: data)

        #expect(decoded.defaultProfile == "work")
        #expect(decoded.profiles.count == 2)
        #expect(decoded.profiles["work"]?.keyId == "KEY2")
    }
}

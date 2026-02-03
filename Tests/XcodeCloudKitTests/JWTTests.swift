import Testing
import Foundation
@testable import XcodeCloudKit

/// Tests for JWT token generation
@Suite("JWT Tests")
struct JWTTests {

    // Test private key in PEM format (this is a test key, not a real one)
    static let testPrivateKey = """
    -----BEGIN PRIVATE KEY-----
    MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQgKzZvKj3vW4XrPqfG
    n5UPM3x5GJqLOG1LRs7VPwN0O4egCgYIKoZIzj0DAQehRANCAAQHyQ9Ja+TAuT9T
    8lNvM3YyYxyEYUDspmruXHxPxZT/U3djFfXLM9L/ABhPpEk1aSaOO/8qqDyxlFAh
    NLh1gGsr
    -----END PRIVATE KEY-----
    """

    private func makeCredentials(keyId: String = "ABC123", issuerId: String = "DEF456") -> Credentials {
        Credentials(
            keyId: keyId,
            issuerId: issuerId,
            privateKey: Self.testPrivateKey
        )
    }

    @Test("JWT generator creates valid token structure")
    func testJWTStructure() throws {
        let credentials = makeCredentials()
        let generator = JWTGenerator(credentials: credentials)

        let token = try generator.generateToken()

        // JWT should have three parts separated by dots
        let parts = token.split(separator: ".")
        #expect(parts.count == 3)

        // Each part should be base64url encoded
        for part in parts {
            #expect(!part.isEmpty)
            // Base64url characters only
            let validChars = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
            #expect(part.unicodeScalars.allSatisfy { validChars.contains($0) })
        }
    }

    @Test("JWT header contains correct algorithm and key ID")
    func testJWTHeader() throws {
        let credentials = makeCredentials(keyId: "TESTKEY123", issuerId: "ISSUER456")
        let generator = JWTGenerator(credentials: credentials)

        let token = try generator.generateToken()
        let parts = token.split(separator: ".")

        // Decode header (first part)
        let headerData = base64URLDecode(String(parts[0]))!
        let header = try JSONSerialization.jsonObject(with: headerData) as! [String: Any]

        #expect(header["alg"] as? String == "ES256")
        #expect(header["kid"] as? String == "TESTKEY123")
        #expect(header["typ"] as? String == "JWT")
    }

    @Test("JWT payload contains required claims")
    func testJWTPayload() throws {
        let credentials = makeCredentials(keyId: "TESTKEY123", issuerId: "ISSUER456")
        let generator = JWTGenerator(credentials: credentials)

        let token = try generator.generateToken()
        let parts = token.split(separator: ".")

        // Decode payload (second part)
        let payloadData = base64URLDecode(String(parts[1]))!
        let payload = try JSONSerialization.jsonObject(with: payloadData) as! [String: Any]

        #expect(payload["iss"] as? String == "ISSUER456")
        #expect(payload["aud"] as? String == "appstoreconnect-v1")

        // Check exp is in the future
        let exp = payload["exp"] as? Int
        #expect(exp != nil)
        #expect(exp! > Int(Date().timeIntervalSince1970))

        // Check iat is roughly now
        let iat = payload["iat"] as? Int
        #expect(iat != nil)
        let now = Int(Date().timeIntervalSince1970)
        #expect(abs(iat! - now) < 5) // Within 5 seconds
    }

    @Test("JWT generator throws for invalid key")
    func testInvalidKey() {
        let credentials = Credentials(
            keyId: "ABC123",
            issuerId: "DEF456",
            privateKey: "not a valid key"
        )
        let generator = JWTGenerator(credentials: credentials)

        #expect(throws: Error.self) {
            _ = try generator.generateToken()
        }
    }

    @Test("JWT generator throws for empty key")
    func testEmptyKey() {
        let credentials = Credentials(
            keyId: "ABC123",
            issuerId: "DEF456",
            privateKey: ""
        )
        let generator = JWTGenerator(credentials: credentials)

        #expect(throws: Error.self) {
            _ = try generator.generateToken()
        }
    }

    // Helper to decode base64url
    private func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Pad to multiple of 4
        while base64.count % 4 != 0 {
            base64.append("=")
        }

        return Data(base64Encoded: base64)
    }
}

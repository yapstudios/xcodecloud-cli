import Foundation
import Crypto

/// Generates JWT tokens for App Store Connect API authentication
public struct JWTGenerator: Sendable {
    private let credentials: Credentials
    private let expirationDuration: TimeInterval

    /// Creates a new JWT generator
    /// - Parameters:
    ///   - credentials: The API credentials
    ///   - expirationDuration: Token expiration in seconds (max 20 minutes = 1200 seconds)
    public init(credentials: Credentials, expirationDuration: TimeInterval = 1200) {
        self.credentials = credentials
        self.expirationDuration = min(expirationDuration, 1200)
    }

    /// Generates a signed JWT token
    public func generateToken() throws -> String {
        let header = JWTHeader(alg: "ES256", kid: credentials.keyId, typ: "JWT")
        let now = Date()
        let payload = JWTPayload(
            iss: credentials.issuerId,
            iat: Int(now.timeIntervalSince1970),
            exp: Int(now.addingTimeInterval(expirationDuration).timeIntervalSince1970),
            aud: "appstoreconnect-v1"
        )

        let headerData = try JSONEncoder().encode(header)
        let payloadData = try JSONEncoder().encode(payload)

        let headerBase64 = headerData.base64URLEncodedString()
        let payloadBase64 = payloadData.base64URLEncodedString()

        let signingInput = "\(headerBase64).\(payloadBase64)"
        let signature = try sign(signingInput)

        return "\(signingInput).\(signature)"
    }

    private func sign(_ input: String) throws -> String {
        let privateKey = try parsePrivateKey()
        let inputData = Data(input.utf8)
        let signature = try privateKey.signature(for: inputData)
        return signature.rawRepresentation.base64URLEncodedString()
    }

    private func parsePrivateKey() throws -> P256.Signing.PrivateKey {
        // Remove PEM headers and whitespace
        var keyContent = credentials.privateKey
            .replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: " ", with: "")

        guard let keyData = Data(base64Encoded: keyContent) else {
            throw CLIError.invalidPrivateKey("Could not decode base64 key data")
        }

        // The .p8 file contains a PKCS#8 wrapped key
        // We need to extract the raw EC private key
        do {
            return try P256.Signing.PrivateKey(derRepresentation: keyData)
        } catch {
            throw CLIError.invalidPrivateKey("Could not parse private key: \(error.localizedDescription)")
        }
    }
}

private struct JWTHeader: Codable {
    let alg: String
    let kid: String
    let typ: String
}

private struct JWTPayload: Codable {
    let iss: String
    let iat: Int
    let exp: Int
    let aud: String
}

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

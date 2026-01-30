import Foundation

/// Provides authentication for API requests
public actor AuthProvider {
    private let credentials: Credentials
    private let jwtGenerator: JWTGenerator
    private var cachedToken: String?
    private var tokenExpiration: Date?

    public init(credentials: Credentials) {
        self.credentials = credentials
        self.jwtGenerator = JWTGenerator(credentials: credentials)
    }

    /// Gets a valid JWT token, generating a new one if needed
    public func getToken() throws -> String {
        // Return cached token if still valid (with 60 second buffer)
        if let token = cachedToken,
           let expiration = tokenExpiration,
           expiration > Date().addingTimeInterval(60) {
            return token
        }

        // Generate new token
        let token = try jwtGenerator.generateToken()
        cachedToken = token
        tokenExpiration = Date().addingTimeInterval(1140) // 19 minutes

        return token
    }

    /// Invalidates the cached token
    public func invalidateToken() {
        cachedToken = nil
        tokenExpiration = nil
    }
}

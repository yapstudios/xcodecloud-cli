import Foundation

/// Client for the App Store Connect API
public actor APIClient {
    private let authProvider: AuthProvider
    private let baseURL = URL(string: "https://api.appstoreconnect.apple.com")!
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(credentials: Credentials) {
        self.authProvider = AuthProvider(credentials: credentials)

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    // MARK: - Products

    public func listProducts(limit: Int? = nil, cursor: String? = nil) async throws -> APIListResponse<CiProduct> {
        try await request(.listProducts(limit: limit, cursor: cursor))
    }

    public func getProduct(id: String) async throws -> APIResponse<CiProduct> {
        try await request(.getProduct(id: id))
    }

    // MARK: - Workflows

    public func listWorkflows(productId: String, limit: Int? = nil, cursor: String? = nil) async throws -> APIListResponse<CiWorkflow> {
        try await request(.listWorkflows(productId: productId, limit: limit, cursor: cursor))
    }

    public func getWorkflow(id: String) async throws -> APIResponse<CiWorkflow> {
        try await request(.getWorkflow(id: id))
    }

    // MARK: - Build Runs

    public func listBuildRuns(workflowId: String? = nil, limit: Int? = nil, cursor: String? = nil) async throws -> APIListResponse<CiBuildRun> {
        try await request(.listBuildRuns(workflowId: workflowId, limit: limit, cursor: cursor))
    }

    public func getBuildRun(id: String) async throws -> APIResponse<CiBuildRun> {
        try await request(.getBuildRun(id: id))
    }

    public func startBuildRun(workflowId: String, gitReference: GitReference? = nil) async throws -> APIResponse<CiBuildRun> {
        let body = CiBuildRunCreateRequest(workflowId: workflowId, gitReference: gitReference)
        return try await request(.startBuildRun, body: body)
    }

    // MARK: - Build Actions

    public func listBuildActions(buildRunId: String) async throws -> APIListResponse<CiBuildAction> {
        try await request(.listBuildActions(buildRunId: buildRunId))
    }

    // MARK: - Issues

    public func listIssues(buildActionId: String) async throws -> APIListResponse<CiIssue> {
        try await request(.listIssues(buildActionId: buildActionId))
    }

    // MARK: - Test Results

    public func listTestResults(buildActionId: String) async throws -> APIListResponse<CiTestResult> {
        try await request(.listTestResults(buildActionId: buildActionId))
    }

    // MARK: - Artifacts

    public func listArtifacts(buildActionId: String) async throws -> APIListResponse<CiArtifact> {
        try await request(.listArtifacts(buildActionId: buildActionId))
    }

    public func getArtifact(id: String) async throws -> APIResponse<CiArtifact> {
        try await request(.getArtifact(id: id))
    }

    public func downloadArtifact(url: URL, to destination: URL) async throws {
        let (tempURL, response) = try await session.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw CLIError.apiError(statusCode: statusCode, message: "Failed to download artifact")
        }

        try FileManager.default.moveItem(at: tempURL, to: destination)
    }

    // MARK: - Private

    private func request<T: Codable & Sendable>(_ endpoint: Endpoint) async throws -> T {
        let urlRequest = try await buildRequest(endpoint)
        return try await execute(urlRequest)
    }

    private func request<T: Codable & Sendable, B: Codable & Sendable>(_ endpoint: Endpoint, body: B) async throws -> T {
        var urlRequest = try await buildRequest(endpoint)
        urlRequest.httpBody = try encoder.encode(body)
        return try await execute(urlRequest)
    }

    private func buildRequest(_ endpoint: Endpoint) async throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false)!
        let queryItems = endpoint.queryItems
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = endpoint.method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let token = try await authProvider.getToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        return request
    }

    private func execute<T: Codable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw CLIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CLIError.networkError(URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw CLIError.decodingError(error)
            }
        case 401:
            await authProvider.invalidateToken()
            throw CLIError.unauthorized
        case 403:
            throw CLIError.forbidden
        case 404:
            throw CLIError.notFound("Resource not found")
        case 429:
            throw CLIError.rateLimited
        case 500...599:
            throw CLIError.serverError(httpResponse.statusCode)
        default:
            // Try to parse error response
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data),
               let firstError = errorResponse.errors.first {
                throw CLIError.apiError(statusCode: httpResponse.statusCode, message: firstError.detail ?? firstError.title)
            }
            throw CLIError.apiError(statusCode: httpResponse.statusCode, message: "Unknown error")
        }
    }
}

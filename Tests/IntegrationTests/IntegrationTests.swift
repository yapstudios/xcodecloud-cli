import Foundation
import Testing
import XcodeCloudKit

private let hasCredentials: Bool = {
    let resolver = CredentialResolver()
    return (try? resolver.resolve()) != nil
}()

/// Integration tests that hit the real App Store Connect API.
///
/// These tests are skipped automatically when no credentials are available.
/// Credentials are resolved using the standard resolution order:
///
///   1. Environment variables (XCODE_CLOUD_KEY_ID, XCODE_CLOUD_ISSUER_ID,
///      XCODE_CLOUD_PRIVATE_KEY_PATH or XCODE_CLOUD_PRIVATE_KEY)
///   2. Project-local config (.xcodecloud/config.json)
///   3. Global config (~/.xcodecloud/config.json)
///
/// Examples:
///
///   # Using environment variables
///   XCODE_CLOUD_KEY_ID=... XCODE_CLOUD_ISSUER_ID=... \
///   XCODE_CLOUD_PRIVATE_KEY_PATH=~/.xcodecloud/key.p8 \
///   swift test --filter IntegrationTests
///
///   # Using existing config file (no env vars needed)
///   swift test --filter IntegrationTests
///
@Suite("Integration Tests", .enabled(if: hasCredentials, "No credentials available — set env vars or configure ~/.xcodecloud/config.json"))
struct IntegrationTests {

    static var client: APIClient {
        let resolver = CredentialResolver()
        let credentials = try! resolver.resolve()
        return APIClient(credentials: credentials)
    }

    // MARK: - Products

    @Test("List products returns data")
    func listProducts() async throws {
        let response = try await Self.client.listProducts(limit: 5)
        #expect(!response.data.isEmpty, "Expected at least one CI product")

        let product = response.data[0]
        #expect(product.id.isEmpty == false)
        #expect(product.type == "ciProducts")
        #expect(product.attributes?.name != nil)
        #expect(product.attributes?.productType != nil)
    }

    @Test("Get product by ID")
    func getProduct() async throws {
        let list = try await Self.client.listProducts(limit: 1)
        try #require(!list.data.isEmpty, "No products available to test with")
        let productId = list.data[0].id

        let response = try await Self.client.getProduct(id: productId)
        #expect(response.data.id == productId)
        #expect(response.data.attributes?.name != nil)
    }

    @Test("List all products with pagination")
    func listAllProducts() async throws {
        let response = try await Self.client.listAllProducts(limit: 2)
        #expect(!response.data.isEmpty)

        for product in response.data {
            #expect(product.id.isEmpty == false)
            #expect(product.attributes?.name != nil)
        }
    }

    // MARK: - Workflows

    @Test("List workflows for a product")
    func listWorkflows() async throws {
        let products = try await Self.client.listProducts(limit: 1)
        try #require(!products.data.isEmpty, "No products available")

        let response = try await Self.client.listWorkflows(productId: products.data[0].id, limit: 5)
        if !response.data.isEmpty {
            let workflow = response.data[0]
            #expect(workflow.type == "ciWorkflows")
            #expect(workflow.attributes?.name != nil)
        }
    }

    @Test("Get workflow by ID")
    func getWorkflow() async throws {
        let products = try await Self.client.listProducts(limit: 1)
        try #require(!products.data.isEmpty, "No products available")

        let workflows = try await Self.client.listWorkflows(productId: products.data[0].id, limit: 1)
        try #require(!workflows.data.isEmpty, "No workflows available")

        let response = try await Self.client.getWorkflow(id: workflows.data[0].id)
        #expect(response.data.id == workflows.data[0].id)
        #expect(response.data.attributes?.name != nil)
    }

    // MARK: - Builds

    /// Finds a build by searching across all products and workflows.
    private static func findBuild(client: APIClient) async throws -> (workflowId: String, build: CiBuildRun)? {
        let products = try await client.listProducts(limit: 10)
        for product in products.data {
            let workflows = try await client.listWorkflows(productId: product.id, limit: 10)
            for workflow in workflows.data {
                let builds = try await client.listBuildRuns(workflowId: workflow.id, limit: 1)
                if let build = builds.data.first {
                    return (workflow.id, build)
                }
            }
        }
        return nil
    }

    @Test("List builds for a workflow")
    func listBuilds() async throws {
        let result = try await Self.findBuild(client: Self.client)
        try #require(result != nil, "No builds found across any workflow")

        let response = try await Self.client.listBuildRuns(workflowId: result!.workflowId, limit: 5)
        #expect(!response.data.isEmpty)

        let build = response.data[0]
        #expect(build.type == "ciBuildRuns")
        #expect(build.attributes?.number != nil)
        #expect(build.attributes?.executionProgress != nil)
    }

    @Test("Get build by ID")
    func getBuild() async throws {
        let result = try await Self.findBuild(client: Self.client)
        try #require(result != nil, "No builds found across any workflow")

        let response = try await Self.client.getBuildRun(id: result!.build.id)
        #expect(response.data.id == result!.build.id)
        #expect(response.data.attributes?.number != nil)
    }

    @Test("List build actions")
    func listBuildActions() async throws {
        let result = try await Self.findBuild(client: Self.client)
        try #require(result != nil, "No builds found across any workflow")

        let response = try await Self.client.listBuildActions(buildRunId: result!.build.id)
        if !response.data.isEmpty {
            let action = response.data[0]
            #expect(action.type == "ciBuildActions")
            #expect(action.attributes?.name != nil)
            #expect(action.attributes?.actionType != nil)
        }
    }

    // MARK: - Error Handling

    @Test("Get product with invalid ID returns not found")
    func getProductNotFound() async throws {
        do {
            _ = try await Self.client.getProduct(id: "INVALID-ID-THAT-DOES-NOT-EXIST")
            Issue.record("Expected CLIError.notFound")
        } catch let error as CLIError {
            if case .notFound = error {
                // Expected
            } else {
                Issue.record("Expected CLIError.notFound, got \(error)")
            }
        }
    }

    @Test("List builds without workflow ID returns forbidden")
    func listBuildsWithoutWorkflowForbidden() async throws {
        do {
            _ = try await Self.client.listBuildRuns(limit: 1)
            Issue.record("Expected CLIError.forbidden")
        } catch let error as CLIError {
            if case .forbidden = error {
                // Expected
            } else {
                Issue.record("Expected CLIError.forbidden, got \(error)")
            }
        }
    }
}

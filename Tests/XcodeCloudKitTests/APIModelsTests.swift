import Testing
import Foundation
@testable import XcodeCloudKit

/// Tests for API model parsing and serialization
@Suite("API Models Tests")
struct APIModelsTests {

    // MARK: - CiProduct

    @Test("CiProduct decodes from JSON")
    func testCiProductDecoding() throws {
        let json = """
        {
            "type": "ciProducts",
            "id": "product123",
            "attributes": {
                "name": "MyApp",
                "productType": "APP",
                "createdDate": "2024-01-15T10:30:00Z"
            }
        }
        """
        let data = json.data(using: .utf8)!
        let product = try JSONDecoder().decode(CiProduct.self, from: data)

        #expect(product.id == "product123")
        #expect(product.type == "ciProducts")
        #expect(product.attributes?.name == "MyApp")
        #expect(product.attributes?.productType == "APP")
    }

    @Test("CiProduct handles missing attributes")
    func testCiProductMissingAttributes() throws {
        let json = """
        {
            "type": "ciProducts",
            "id": "product123"
        }
        """
        let data = json.data(using: .utf8)!
        let product = try JSONDecoder().decode(CiProduct.self, from: data)

        #expect(product.id == "product123")
        #expect(product.attributes == nil)
    }

    // MARK: - CiWorkflow

    @Test("CiWorkflow decodes from JSON")
    func testCiWorkflowDecoding() throws {
        let json = """
        {
            "type": "ciWorkflows",
            "id": "workflow123",
            "attributes": {
                "name": "Release Build",
                "description": "Builds for App Store",
                "isEnabled": true,
                "isLockedForEditing": false
            }
        }
        """
        let data = json.data(using: .utf8)!
        let workflow = try JSONDecoder().decode(CiWorkflow.self, from: data)

        #expect(workflow.id == "workflow123")
        #expect(workflow.attributes?.name == "Release Build")
        #expect(workflow.attributes?.description == "Builds for App Store")
        #expect(workflow.attributes?.isEnabled == true)
    }

    // MARK: - CiBuildRun

    @Test("CiBuildRun decodes from JSON")
    func testCiBuildRunDecoding() throws {
        let json = """
        {
            "type": "ciBuildRuns",
            "id": "build123",
            "attributes": {
                "number": 42,
                "executionProgress": "COMPLETE",
                "completionStatus": "SUCCEEDED",
                "startReason": "MANUAL",
                "startedDate": "2024-01-15T10:30:00Z",
                "finishedDate": "2024-01-15T10:45:00Z",
                "sourceCommit": {
                    "commitSha": "abc123def456",
                    "message": "Fix bug in login",
                    "author": {
                        "displayName": "John Doe"
                    }
                }
            }
        }
        """
        let data = json.data(using: .utf8)!
        let build = try JSONDecoder().decode(CiBuildRun.self, from: data)

        #expect(build.id == "build123")
        #expect(build.attributes?.number == 42)
        #expect(build.attributes?.executionProgress == "COMPLETE")
        #expect(build.attributes?.completionStatus == "SUCCEEDED")
        #expect(build.attributes?.sourceCommit?.commitSha == "abc123def456")
        #expect(build.attributes?.sourceCommit?.author?.displayName == "John Doe")
    }

    @Test("CiBuildRun handles running build")
    func testCiBuildRunRunning() throws {
        let json = """
        {
            "type": "ciBuildRuns",
            "id": "build456",
            "attributes": {
                "number": 43,
                "executionProgress": "RUNNING",
                "startReason": "GIT_REF_CHANGE"
            }
        }
        """
        let data = json.data(using: .utf8)!
        let build = try JSONDecoder().decode(CiBuildRun.self, from: data)

        #expect(build.attributes?.executionProgress == "RUNNING")
        #expect(build.attributes?.completionStatus == nil)
    }

    // MARK: - CiBuildAction

    @Test("CiBuildAction decodes from JSON")
    func testCiBuildActionDecoding() throws {
        let json = """
        {
            "type": "ciBuildActions",
            "id": "action123",
            "attributes": {
                "name": "Build - iOS",
                "actionType": "BUILD",
                "executionProgress": "COMPLETE",
                "completionStatus": "SUCCEEDED",
                "startedDate": "2024-01-15T10:30:00Z",
                "finishedDate": "2024-01-15T10:35:00Z"
            }
        }
        """
        let data = json.data(using: .utf8)!
        let action = try JSONDecoder().decode(CiBuildAction.self, from: data)

        #expect(action.id == "action123")
        #expect(action.attributes?.name == "Build - iOS")
        #expect(action.attributes?.actionType == "BUILD")
        #expect(action.attributes?.completionStatus == "SUCCEEDED")
    }

    @Test("CiBuildAction handles TEST action type")
    func testCiBuildActionTest() throws {
        let json = """
        {
            "type": "ciBuildActions",
            "id": "action456",
            "attributes": {
                "name": "Test - iOS",
                "actionType": "TEST",
                "completionStatus": "FAILED"
            }
        }
        """
        let data = json.data(using: .utf8)!
        let action = try JSONDecoder().decode(CiBuildAction.self, from: data)

        #expect(action.attributes?.actionType == "TEST")
        #expect(action.attributes?.completionStatus == "FAILED")
    }

    // MARK: - CiIssue

    @Test("CiIssue decodes from JSON")
    func testCiIssueDecoding() throws {
        let json = """
        {
            "type": "ciIssues",
            "id": "issue123",
            "attributes": {
                "issueType": "ERROR",
                "message": "Cannot find type 'Foo' in scope",
                "fileSource": {
                    "path": "Sources/MyApp/Foo.swift",
                    "lineNumber": 42
                }
            }
        }
        """
        let data = json.data(using: .utf8)!
        let issue = try JSONDecoder().decode(CiIssue.self, from: data)

        #expect(issue.id == "issue123")
        #expect(issue.attributes?.issueType == "ERROR")
        #expect(issue.attributes?.message == "Cannot find type 'Foo' in scope")
        #expect(issue.attributes?.fileSource?.path == "Sources/MyApp/Foo.swift")
        #expect(issue.attributes?.fileSource?.lineNumber == 42)
    }

    @Test("CiIssue handles warning")
    func testCiIssueWarning() throws {
        let json = """
        {
            "type": "ciIssues",
            "id": "issue456",
            "attributes": {
                "issueType": "WARNING",
                "message": "Variable 'x' was never used"
            }
        }
        """
        let data = json.data(using: .utf8)!
        let issue = try JSONDecoder().decode(CiIssue.self, from: data)

        #expect(issue.attributes?.issueType == "WARNING")
        #expect(issue.attributes?.fileSource == nil)
    }

    // MARK: - CiTestResult

    @Test("CiTestResult decodes from JSON")
    func testCiTestResultDecoding() throws {
        let json = """
        {
            "type": "ciTestResults",
            "id": "test123",
            "attributes": {
                "className": "MyAppTests",
                "name": "testLogin",
                "status": "SUCCESS"
            }
        }
        """
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(CiTestResult.self, from: data)

        #expect(result.id == "test123")
        #expect(result.attributes?.className == "MyAppTests")
        #expect(result.attributes?.name == "testLogin")
        #expect(result.attributes?.status == "SUCCESS")
    }

    @Test("CiTestResult handles failure with message")
    func testCiTestResultFailure() throws {
        let json = """
        {
            "type": "ciTestResults",
            "id": "test456",
            "attributes": {
                "className": "MyAppTests",
                "name": "testLogout",
                "status": "FAILURE",
                "message": "XCTAssertEqual failed: (1) is not equal to (2)",
                "fileSource": {
                    "path": "Tests/MyAppTests/LogoutTests.swift",
                    "lineNumber": 25
                }
            }
        }
        """
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(CiTestResult.self, from: data)

        #expect(result.attributes?.status == "FAILURE")
        #expect(result.attributes?.message?.contains("XCTAssertEqual") == true)
        #expect(result.attributes?.fileSource?.lineNumber == 25)
    }

    // MARK: - CiArtifact

    @Test("CiArtifact decodes from JSON")
    func testCiArtifactDecoding() throws {
        let json = """
        {
            "type": "ciArtifacts",
            "id": "artifact123",
            "attributes": {
                "fileName": "MyApp.ipa",
                "fileType": "ARCHIVE",
                "fileSize": 52428800,
                "downloadUrl": "https://example.com/download/artifact123"
            }
        }
        """
        let data = json.data(using: .utf8)!
        let artifact = try JSONDecoder().decode(CiArtifact.self, from: data)

        #expect(artifact.id == "artifact123")
        #expect(artifact.attributes?.fileName == "MyApp.ipa")
        #expect(artifact.attributes?.fileType == "ARCHIVE")
        #expect(artifact.attributes?.fileSize == 52428800)
        #expect(artifact.attributes?.downloadUrl?.contains("artifact123") == true)
    }

    // MARK: - API Response Wrappers

    @Test("APIResponse decodes single object")
    func testAPIResponseDecoding() throws {
        let json = """
        {
            "data": {
                "type": "ciProducts",
                "id": "product123",
                "attributes": {
                    "name": "MyApp"
                }
            }
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(APIResponse<CiProduct>.self, from: data)

        #expect(response.data.id == "product123")
        #expect(response.data.attributes?.name == "MyApp")
    }

    @Test("APIListResponse decodes array with paging")
    func testAPIListResponseDecoding() throws {
        let json = """
        {
            "data": [
                {
                    "type": "ciProducts",
                    "id": "product1",
                    "attributes": { "name": "App1" }
                },
                {
                    "type": "ciProducts",
                    "id": "product2",
                    "attributes": { "name": "App2" }
                }
            ],
            "meta": {
                "paging": {
                    "total": 10,
                    "limit": 2
                }
            }
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(APIListResponse<CiProduct>.self, from: data)

        #expect(response.data.count == 2)
        #expect(response.data[0].id == "product1")
        #expect(response.data[1].attributes?.name == "App2")
        #expect(response.meta?.paging?.total == 10)
    }

    @Test("APIListResponse handles empty array")
    func testAPIListResponseEmpty() throws {
        let json = """
        {
            "data": []
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(APIListResponse<CiProduct>.self, from: data)

        #expect(response.data.isEmpty)
    }

    // MARK: - Error Response

    @Test("APIErrorResponse decodes error")
    func testAPIErrorResponseDecoding() throws {
        let json = """
        {
            "errors": [
                {
                    "status": "401",
                    "code": "NOT_AUTHORIZED",
                    "title": "Authentication credentials are missing or invalid.",
                    "detail": "The request requires authentication."
                }
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(APIErrorResponse.self, from: data)

        #expect(response.errors.count == 1)
        #expect(response.errors[0].status == "401")
        #expect(response.errors[0].code == "NOT_AUTHORIZED")
    }
}

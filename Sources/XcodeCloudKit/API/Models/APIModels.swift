import Foundation

// MARK: - Common Types

/// Standard JSON:API response wrapper
public struct APIResponse<T: Codable & Sendable>: Codable, Sendable {
    public let data: T
    public let included: [IncludedResource]?
    public let links: ResourceLinks?
    public let meta: ResponseMeta?
}

/// Response for collections
public struct APIListResponse<T: Codable & Sendable>: Codable, Sendable {
    public let data: [T]
    public let included: [IncludedResource]?
    public let links: PageLinks?
    public let meta: ResponseMeta?

    public init(data: [T], included: [IncludedResource]?, links: PageLinks?, meta: ResponseMeta?) {
        self.data = data
        self.included = included
        self.links = links
        self.meta = meta
    }
}

/// Included resource (polymorphic)
public struct IncludedResource: Codable, Sendable {
    public let type: String
    public let id: String
    public let attributes: [String: AnyCodable]?
}

/// Resource links
public struct ResourceLinks: Codable, Sendable {
    public let `self`: String?
}

/// Pagination links
public struct PageLinks: Codable, Sendable {
    public let `self`: String?
    public let first: String?
    public let next: String?
}

/// Response metadata
public struct ResponseMeta: Codable, Sendable {
    public let paging: Paging?
}

/// Paging info
public struct Paging: Codable, Sendable {
    public let total: Int?
    public let limit: Int?
}

/// API error response
public struct APIErrorResponse: Codable, Sendable {
    public let errors: [APIErrorDetail]
}

public struct APIErrorDetail: Codable, Sendable {
    public let id: String?
    public let status: String
    public let code: String
    public let title: String
    public let detail: String?
}

// MARK: - CI Products

public struct CiProduct: Codable, Sendable, Identifiable {
    public let type: String
    public let id: String
    public let attributes: CiProductAttributes?
    public let relationships: CiProductRelationships?
}

public struct CiProductAttributes: Codable, Sendable {
    public let name: String?
    public let createdDate: String?
    public let productType: String?
}

public struct CiProductRelationships: Codable, Sendable {
    public let app: Relationship?
    public let bundleId: Relationship?
    public let primaryRepositories: RelationshipList?
}

extension CiProduct {
    /// Look up the bundle identifier from included resources.
    /// Checks bundleId relationship first, then falls back to app relationship.
    public func bundleId(from included: [IncludedResource]?) -> String? {
        guard let included else { return nil }

        if let ref = relationships?.bundleId?.data?.id,
           let identifier = included.first(where: { $0.type == "bundleIds" && $0.id == ref })?
               .attributes?["identifier"]?.value as? String {
            return identifier
        }

        if let appId = relationships?.app?.data?.id,
           let identifier = included.first(where: { $0.type == "apps" && $0.id == appId })?
               .attributes?["bundleId"]?.value as? String {
            return identifier
        }

        return nil
    }
}

// MARK: - CI Workflows

public struct CiWorkflow: Codable, Sendable, Identifiable {
    public let type: String
    public let id: String
    public let attributes: CiWorkflowAttributes?
    public let relationships: CiWorkflowRelationships?
}

public struct CiWorkflowAttributes: Codable, Sendable {
    public let name: String?
    public let description: String?
    public let branchStartCondition: BranchStartCondition?
    public let tagStartCondition: TagStartCondition?
    public let pullRequestStartCondition: PullRequestStartCondition?
    public let scheduledStartCondition: ScheduledStartCondition?
    public let manualBranchStartCondition: ManualBranchStartCondition?
    public let actions: [CiAction]?
    public let isEnabled: Bool?
    public let isLockedForEditing: Bool?
    public let clean: Bool?
    public let containerFilePath: String?
    public let lastModifiedDate: String?
}

public struct CiWorkflowRelationships: Codable, Sendable {
    public let product: Relationship?
    public let repository: Relationship?
    public let xcodeVersion: Relationship?
    public let macOsVersion: Relationship?
}

// MARK: - Workflow Start Conditions

public struct BranchStartCondition: Codable, Sendable {
    public let source: SourcePattern?
    public let filesAndFoldersRule: FilesAndFoldersRule?
    public let autoCancel: Bool?
}

public struct TagStartCondition: Codable, Sendable {
    public let source: SourcePattern?
    public let filesAndFoldersRule: FilesAndFoldersRule?
    public let autoCancel: Bool?
}

public struct PullRequestStartCondition: Codable, Sendable {
    public let source: SourcePattern?
    public let destination: SourcePattern?
    public let filesAndFoldersRule: FilesAndFoldersRule?
    public let autoCancel: Bool?
}

public struct ScheduledStartCondition: Codable, Sendable {
    public let source: SourcePattern?
    public let schedule: Schedule?
}

public struct ManualBranchStartCondition: Codable, Sendable {
    public let source: SourcePattern?
}

public struct SourcePattern: Codable, Sendable {
    public let isAllMatch: Bool?
    public let patterns: [Pattern]?
}

public struct Pattern: Codable, Sendable {
    public let pattern: String?
    public let isPrefix: Bool?
}

public struct FilesAndFoldersRule: Codable, Sendable {
    public let mode: String?
    public let matchers: [Matcher]?
}

public struct Matcher: Codable, Sendable {
    public let directory: String?
    public let fileExtension: String?
    public let fileName: String?
}

public struct Schedule: Codable, Sendable {
    public let frequency: String?
    public let days: [String]?
    public let hour: Int?
    public let minute: Int?
    public let timezone: String?
}

// MARK: - CI Actions

public struct CiAction: Codable, Sendable {
    public let name: String?
    public let actionType: String?
    public let destination: String?
    public let buildDistributionAudience: String?
    public let testConfiguration: TestConfiguration?
    public let scheme: String?
    public let platform: String?
    public let isRequiredToPass: Bool?
}

public struct TestConfiguration: Codable, Sendable {
    public let kind: String?
    public let testPlanName: String?
    public let testDestinations: [TestDestination]?
}

public struct TestDestination: Codable, Sendable {
    public let deviceTypeName: String?
    public let deviceTypeIdentifier: String?
    public let runtimeName: String?
    public let runtimeIdentifier: String?
}

// MARK: - CI Build Runs

public struct CiBuildRun: Codable, Sendable, Identifiable {
    public let type: String
    public let id: String
    public let attributes: CiBuildRunAttributes?
    public let relationships: CiBuildRunRelationships?
}

public struct CiBuildRunAttributes: Codable, Sendable {
    public let number: Int?
    public let createdDate: String?
    public let startedDate: String?
    public let finishedDate: String?
    public let sourceCommit: SourceCommit?
    public let destinationCommit: SourceCommit?
    public let isPullRequestBuild: Bool?
    public let executionProgress: String?
    public let completionStatus: String?
    public let startReason: String?
    public let cancelReason: String?
}

public struct SourceCommit: Codable, Sendable {
    public let commitSha: String?
    public let message: String?
    public let author: Author?
    public let webUrl: String?
}

public struct Author: Codable, Sendable {
    public let displayName: String?
    public let avatarUrl: String?
}

public struct CiBuildRunRelationships: Codable, Sendable {
    public let builds: RelationshipList?
    public let workflow: Relationship?
    public let product: Relationship?
    public let sourceBranchOrTag: Relationship?
    public let destinationBranch: Relationship?
    public let pullRequest: Relationship?
}

// MARK: - CI Build Actions

public struct CiBuildAction: Codable, Sendable, Identifiable {
    public let type: String
    public let id: String
    public let attributes: CiBuildActionAttributes?
}

public struct CiBuildActionAttributes: Codable, Sendable {
    public let name: String?
    public let actionType: String?
    public let startedDate: String?
    public let finishedDate: String?
    public let executionProgress: String?
    public let completionStatus: String?
    public let isRequiredToPass: Bool?
}

// MARK: - CI Issues

public struct CiIssue: Codable, Sendable, Identifiable {
    public let type: String
    public let id: String
    public let attributes: CiIssueAttributes?
}

public struct CiIssueAttributes: Codable, Sendable {
    public let issueType: String?
    public let message: String?
    public let fileSource: FileSource?
    public let category: String?
}

public struct FileSource: Codable, Sendable {
    public let path: String?
    public let lineNumber: Int?
}

// MARK: - CI Test Results

public struct CiTestResult: Codable, Sendable, Identifiable {
    public let type: String
    public let id: String
    public let attributes: CiTestResultAttributes?
}

public struct CiTestResultAttributes: Codable, Sendable {
    public let className: String?
    public let name: String?
    public let status: String?  // EXPECTED_FAILURE, FAILURE, SKIPPED, SUCCESS
    public let fileSource: FileSource?
    public let message: String?
    public let destinationTestResults: [DestinationTestResult]?
}

public struct DestinationTestResult: Codable, Sendable {
    public let uuid: String?
    public let deviceName: String?
    public let osVersion: String?
    public let status: String?
    public let duration: Double?
}

// MARK: - CI Artifacts

public struct CiArtifact: Codable, Sendable, Identifiable {
    public let type: String
    public let id: String
    public let attributes: CiArtifactAttributes?
}

public struct CiArtifactAttributes: Codable, Sendable {
    public let fileType: String?
    public let fileName: String?
    public let fileSize: Int?
    public let downloadUrl: String?
}

// MARK: - Relationships

public struct Relationship: Codable, Sendable {
    public let data: RelationshipData?
    public let links: ResourceLinks?
}

public struct RelationshipData: Codable, Sendable {
    public let type: String
    public let id: String
}

public struct RelationshipList: Codable, Sendable {
    public let data: [RelationshipData]?
    public let links: ResourceLinks?
    public let meta: ResponseMeta?
}

// MARK: - Create Build Run Request

public struct CiBuildRunCreateRequest: Codable, Sendable {
    public let data: CiBuildRunCreateData

    public init(workflowId: String, gitReference: GitReference? = nil) {
        self.data = CiBuildRunCreateData(workflowId: workflowId, gitReference: gitReference)
    }
}

public struct CiBuildRunCreateData: Codable, Sendable {
    public var type: String
    public let attributes: CiBuildRunCreateAttributes?
    public let relationships: CiBuildRunCreateRelationships

    public init(workflowId: String, gitReference: GitReference? = nil) {
        self.type = "ciBuildRuns"
        self.attributes = gitReference.map { CiBuildRunCreateAttributes(sourceBranchOrTag: $0) }
        self.relationships = CiBuildRunCreateRelationships(workflowId: workflowId)
    }
}

public struct CiBuildRunCreateAttributes: Codable, Sendable {
    public let sourceBranchOrTag: GitReference?
}

public struct GitReference: Codable, Sendable {
    public let kind: String  // "BRANCH" or "TAG"
    public let name: String

    public static func branch(_ name: String) -> GitReference {
        GitReference(kind: "BRANCH", name: name)
    }

    public static func tag(_ name: String) -> GitReference {
        GitReference(kind: "TAG", name: name)
    }
}

public struct CiBuildRunCreateRelationships: Codable, Sendable {
    public let workflow: CreateRelationship

    public init(workflowId: String) {
        self.workflow = CreateRelationship(id: workflowId, type: "ciWorkflows")
    }
}

public struct CreateRelationship: Codable, Sendable {
    public let data: RelationshipData

    public init(id: String, type: String) {
        self.data = RelationshipData(type: type, id: id)
    }
}

// MARK: - AnyCodable helper for polymorphic included resources

public struct AnyCodable: Codable, @unchecked Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unable to encode value"))
        }
    }
}

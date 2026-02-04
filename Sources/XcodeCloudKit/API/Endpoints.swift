import Foundation

/// API endpoint definitions
public enum Endpoint {
    case listProducts(limit: Int?, cursor: String?)
    case getProduct(id: String)
    case listWorkflows(productId: String, limit: Int?, cursor: String?)
    case getWorkflow(id: String)
    case listBuildRuns(workflowId: String?, limit: Int?, cursor: String?)
    case getBuildRun(id: String)
    case startBuildRun
    case cancelBuildRun(id: String)
    case listBuildActions(buildRunId: String)
    case listArtifacts(buildActionId: String)
    case getArtifact(id: String)
    case listIssues(buildActionId: String)
    case getIssue(id: String)
    case listTestResults(buildActionId: String)
    case getTestResult(id: String)

    public var path: String {
        switch self {
        case .listProducts:
            return "/v1/ciProducts"
        case .getProduct(let id):
            return "/v1/ciProducts/\(id)"
        case .listWorkflows(let productId, _, _):
            return "/v1/ciProducts/\(productId)/workflows"
        case .getWorkflow(let id):
            return "/v1/ciWorkflows/\(id)"
        case .listBuildRuns(let workflowId, _, _):
            if let workflowId = workflowId {
                return "/v1/ciWorkflows/\(workflowId)/buildRuns"
            }
            return "/v1/ciBuildRuns"
        case .getBuildRun(let id):
            return "/v1/ciBuildRuns/\(id)"
        case .startBuildRun:
            return "/v1/ciBuildRuns"
        case .cancelBuildRun(let id):
            return "/v1/ciBuildRuns/\(id)"
        case .listBuildActions(let buildRunId):
            return "/v1/ciBuildRuns/\(buildRunId)/actions"
        case .listArtifacts(let buildActionId):
            return "/v1/ciBuildActions/\(buildActionId)/artifacts"
        case .getArtifact(let id):
            return "/v1/ciArtifacts/\(id)"
        case .listIssues(let buildActionId):
            return "/v1/ciBuildActions/\(buildActionId)/issues"
        case .getIssue(let id):
            return "/v1/ciIssues/\(id)"
        case .listTestResults(let buildActionId):
            return "/v1/ciBuildActions/\(buildActionId)/testResults"
        case .getTestResult(let id):
            return "/v1/ciTestResults/\(id)"
        }
    }

    public var method: String {
        switch self {
        case .startBuildRun:
            return "POST"
        case .cancelBuildRun:
            return "DELETE"
        default:
            return "GET"
        }
    }

    public var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []

        switch self {
        case .listProducts(let limit, let cursor):
            items.append(URLQueryItem(name: "include", value: "app,bundleId"))
            if let limit = limit {
                items.append(URLQueryItem(name: "limit", value: String(limit)))
            }
            if let cursor = cursor {
                items.append(URLQueryItem(name: "cursor", value: cursor))
            }
        case .listWorkflows(_, let limit, let cursor),
             .listBuildRuns(_, let limit, let cursor):
            if let limit = limit {
                items.append(URLQueryItem(name: "limit", value: String(limit)))
            }
            if let cursor = cursor {
                items.append(URLQueryItem(name: "cursor", value: cursor))
            }
        default:
            break
        }

        return items
    }
}

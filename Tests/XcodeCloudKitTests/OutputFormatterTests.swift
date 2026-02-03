import Testing
import Foundation
@testable import XcodeCloudKit

/// Tests for output formatting (JSON, table, CSV)
@Suite("Output Formatter Tests")
struct OutputFormatterTests {

    // MARK: - JSON Output

    @Test("JSON formatter outputs valid JSON")
    func testJSONOutput() throws {
        let formatter = OutputFormatter(format: .json, prettyPrint: false, noColor: true)

        let json = """
        {
            "type": "ciProducts",
            "id": "123",
            "attributes": {
                "name": "TestApp",
                "productType": "APP"
            }
        }
        """
        let product = try JSONDecoder().decode(CiProduct.self, from: json.data(using: .utf8)!)

        let output = try formatter.format([product])

        // Should be valid JSON
        let data = output.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: data)
        #expect(parsed is [[String: Any]])
    }

    @Test("Pretty JSON formatter indents output")
    func testPrettyJSONOutput() throws {
        let formatter = OutputFormatter(format: .json, prettyPrint: true, noColor: true)

        let json = """
        {
            "type": "ciProducts",
            "id": "123",
            "attributes": {
                "name": "TestApp",
                "productType": "APP"
            }
        }
        """
        let product = try JSONDecoder().decode(CiProduct.self, from: json.data(using: .utf8)!)

        let output = try formatter.format([product])

        // Pretty JSON should have newlines and indentation
        #expect(output.contains("\n"))
        #expect(output.contains("  "))
    }

    // MARK: - Table Output

    @Test("Table formatter outputs tabular data")
    func testTableOutput() throws {
        let formatter = OutputFormatter(format: .table, prettyPrint: false, noColor: true)

        let json1 = """
        {"type": "ciProducts", "id": "123", "attributes": {"name": "App1", "productType": "APP"}}
        """
        let json2 = """
        {"type": "ciProducts", "id": "456", "attributes": {"name": "App2", "productType": "FRAMEWORK"}}
        """
        let products = [
            try JSONDecoder().decode(CiProduct.self, from: json1.data(using: .utf8)!),
            try JSONDecoder().decode(CiProduct.self, from: json2.data(using: .utf8)!)
        ]

        let output = try formatter.format(products)

        // Should contain both product names
        #expect(output.contains("App1"))
        #expect(output.contains("App2"))
        #expect(output.contains("123"))
        #expect(output.contains("456"))
    }

    // MARK: - CSV Output

    @Test("CSV formatter outputs comma-separated data")
    func testCSVOutput() throws {
        let formatter = OutputFormatter(format: .csv, prettyPrint: false, noColor: true)

        let json1 = """
        {"type": "ciProducts", "id": "123", "attributes": {"name": "App1", "productType": "APP"}}
        """
        let json2 = """
        {"type": "ciProducts", "id": "456", "attributes": {"name": "App2", "productType": "FRAMEWORK"}}
        """
        let products = [
            try JSONDecoder().decode(CiProduct.self, from: json1.data(using: .utf8)!),
            try JSONDecoder().decode(CiProduct.self, from: json2.data(using: .utf8)!)
        ]

        let output = try formatter.format(products)

        // CSV should have comma separators
        #expect(output.contains(","))
        #expect(output.contains("App1"))
        #expect(output.contains("App2"))
    }

    // MARK: - Build Run Formatting

    @Test("Build run formats with status")
    func testBuildRunFormatting() throws {
        let formatter = OutputFormatter(format: .table, prettyPrint: false, noColor: true)

        let json = """
        {
            "type": "ciBuildRuns",
            "id": "build123",
            "attributes": {
                "number": 42,
                "executionProgress": "COMPLETE",
                "completionStatus": "SUCCEEDED"
            }
        }
        """
        let build = try JSONDecoder().decode(CiBuildRun.self, from: json.data(using: .utf8)!)

        let output = try formatter.format([build])

        #expect(output.contains("42") || output.contains("build123"))
    }

    // MARK: - Empty Input

    @Test("Formatter handles empty array")
    func testEmptyArray() throws {
        let formatter = OutputFormatter(format: .table, prettyPrint: false, noColor: true)
        let products: [CiProduct] = []

        let output = try formatter.format(products)

        // Should not crash, may output empty or header only
        #expect(output.isEmpty || output.contains("ID") || output.contains("No"))
    }

    // MARK: - Raw JSON

    @Test("formatRawJSON preserves structure")
    func testFormatRawJSON() throws {
        let formatter = OutputFormatter(format: .json, prettyPrint: false, noColor: true)

        let json = """
        {"type": "ciProducts", "id": "123", "attributes": {"name": "TestApp"}}
        """
        let product = try JSONDecoder().decode(CiProduct.self, from: json.data(using: .utf8)!)
        let response = APIResponse(data: product, included: nil, links: nil, meta: nil)

        let output = try formatter.formatRawJSON(response)

        // Should contain the full response structure
        #expect(output.contains("data"))
        #expect(output.contains("123"))
        #expect(output.contains("TestApp"))
    }
}

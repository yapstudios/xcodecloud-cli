import Foundation

/// Output format options
public enum OutputFormat: String, CaseIterable, Sendable {
    case json
    case table
    case csv
}

/// Protocol for types that can be formatted for output
public protocol OutputFormattable {
    static var tableHeaders: [String] { get }
    var tableRow: [String] { get }
}

/// Formats data for output
public struct OutputFormatter: Sendable {
    public let format: OutputFormat
    public let prettyPrint: Bool
    public let noColor: Bool

    public init(format: OutputFormat = .json, prettyPrint: Bool = false, noColor: Bool = false) {
        self.format = format
        self.prettyPrint = prettyPrint
        self.noColor = noColor
    }

    /// Formats a single item
    public func format<T: Codable & OutputFormattable>(_ item: T) throws -> String {
        switch format {
        case .json:
            return try formatJSON(item)
        case .table:
            return formatTable([item])
        case .csv:
            return formatCSV([item])
        }
    }

    /// Formats a list of items
    public func format<T: Codable & OutputFormattable>(_ items: [T]) throws -> String {
        switch format {
        case .json:
            return try formatJSON(items)
        case .table:
            return formatTable(items)
        case .csv:
            return formatCSV(items)
        }
    }

    /// Formats raw JSON data
    public func formatRawJSON<T: Codable>(_ data: T) throws -> String {
        try formatJSON(data)
    }

    private func formatJSON<T: Codable>(_ data: T) throws -> String {
        let encoder = JSONEncoder()
        if prettyPrint {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        let jsonData = try encoder.encode(data)
        return String(data: jsonData, encoding: .utf8) ?? "{}"
    }

    private func formatTable<T: OutputFormattable>(_ items: [T]) -> String {
        guard !items.isEmpty else {
            return "No results"
        }

        let headers = T.tableHeaders
        let rows = items.map { $0.tableRow }

        // Calculate column widths
        var widths = headers.map { $0.count }
        for row in rows {
            for (i, cell) in row.enumerated() where i < widths.count {
                widths[i] = max(widths[i], cell.count)
            }
        }

        // Build output
        var output = ""

        // Header
        let headerLine = headers.enumerated().map { (i, h) in
            h.padding(toLength: widths[i], withPad: " ", startingAt: 0)
        }.joined(separator: "  ")
        output += colorize(headerLine, .bold) + "\n"

        // Separator
        let separator = widths.map { String(repeating: "-", count: $0) }.joined(separator: "  ")
        output += separator + "\n"

        // Rows
        for row in rows {
            let line = row.enumerated().map { (i, cell) in
                if i < widths.count {
                    return cell.padding(toLength: widths[i], withPad: " ", startingAt: 0)
                }
                return cell
            }.joined(separator: "  ")
            output += line + "\n"
        }

        return output.trimmingCharacters(in: .newlines)
    }

    private func formatCSV<T: OutputFormattable>(_ items: [T]) -> String {
        guard !items.isEmpty else {
            return ""
        }

        let headers = T.tableHeaders
        var output = headers.map { escapeCSV($0) }.joined(separator: ",") + "\n"

        for row in items.map({ $0.tableRow }) {
            output += row.map { escapeCSV($0) }.joined(separator: ",") + "\n"
        }

        return output.trimmingCharacters(in: .newlines)
    }

    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private enum ANSIColor {
        case bold
        case green
        case red
        case yellow
        case cyan

        var code: String {
            switch self {
            case .bold: return "\u{001B}[1m"
            case .green: return "\u{001B}[32m"
            case .red: return "\u{001B}[31m"
            case .yellow: return "\u{001B}[33m"
            case .cyan: return "\u{001B}[36m"
            }
        }

        static let reset = "\u{001B}[0m"
    }

    private func colorize(_ text: String, _ color: ANSIColor) -> String {
        if noColor {
            return text
        }
        return "\(color.code)\(text)\(ANSIColor.reset)"
    }
}

// MARK: - OutputFormattable Conformances

extension CiProduct: OutputFormattable {
    public static var tableHeaders: [String] {
        ["ID", "NAME", "TYPE", "CREATED"]
    }

    public var tableRow: [String] {
        [
            id,
            attributes?.name ?? "-",
            attributes?.productType ?? "-",
            formatDate(attributes?.createdDate) ?? "-"
        ]
    }
}

extension CiWorkflow: OutputFormattable {
    public static var tableHeaders: [String] {
        ["ID", "NAME", "ENABLED", "CLEAN", "MODIFIED"]
    }

    public var tableRow: [String] {
        [
            id,
            attributes?.name ?? "-",
            (attributes?.isEnabled ?? false) ? "Yes" : "No",
            (attributes?.clean ?? false) ? "Yes" : "No",
            formatDate(attributes?.lastModifiedDate) ?? "-"
        ]
    }
}

extension CiBuildRun: OutputFormattable {
    public static var tableHeaders: [String] {
        ["ID", "NUMBER", "STATUS", "PROGRESS", "STARTED", "COMMIT"]
    }

    public var tableRow: [String] {
        [
            id,
            attributes?.number.map(String.init) ?? "-",
            attributes?.completionStatus ?? "-",
            attributes?.executionProgress ?? "-",
            formatDate(attributes?.startedDate) ?? "-",
            String(attributes?.sourceCommit?.commitSha?.prefix(7) ?? "-")
        ]
    }
}

extension CiBuildAction: OutputFormattable {
    public static var tableHeaders: [String] {
        ["ID", "NAME", "TYPE", "STATUS", "REQUIRED"]
    }

    public var tableRow: [String] {
        [
            id,
            attributes?.name ?? "-",
            attributes?.actionType ?? "-",
            attributes?.completionStatus ?? "-",
            (attributes?.isRequiredToPass ?? false) ? "Yes" : "No"
        ]
    }
}

extension CiArtifact: OutputFormattable {
    public static var tableHeaders: [String] {
        ["ID", "FILENAME", "TYPE", "SIZE"]
    }

    public var tableRow: [String] {
        [
            id,
            attributes?.fileName ?? "-",
            attributes?.fileType ?? "-",
            formatFileSize(attributes?.fileSize)
        ]
    }
}

extension CiIssue: OutputFormattable {
    public static var tableHeaders: [String] {
        ["TYPE", "CATEGORY", "FILE", "LINE", "MESSAGE"]
    }

    public var tableRow: [String] {
        [
            attributes?.issueType ?? "-",
            attributes?.category ?? "-",
            attributes?.fileSource?.path ?? "-",
            attributes?.fileSource?.lineNumber.map(String.init) ?? "-",
            attributes?.message ?? "-"
        ]
    }
}

extension CiTestResult: OutputFormattable {
    public static var tableHeaders: [String] {
        ["STATUS", "CLASS", "TEST", "MESSAGE"]
    }

    public var tableRow: [String] {
        [
            attributes?.status ?? "-",
            attributes?.className ?? "-",
            attributes?.name ?? "-",
            attributes?.message ?? "-"
        ]
    }
}

private func formatDate(_ isoDate: String?) -> String? {
    guard let dateStr = isoDate else { return nil }

    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    // Try with fractional seconds first
    if let date = isoFormatter.date(from: dateStr) {
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        return displayFormatter.string(from: date)
    }

    // Try without fractional seconds
    isoFormatter.formatOptions = [.withInternetDateTime]
    if let date = isoFormatter.date(from: dateStr) {
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        return displayFormatter.string(from: date)
    }

    return dateStr
}

private func formatFileSize(_ bytes: Int?) -> String {
    guard let bytes = bytes else { return "-" }

    let units = ["B", "KB", "MB", "GB"]
    var size = Double(bytes)
    var unitIndex = 0

    while size >= 1024 && unitIndex < units.count - 1 {
        size /= 1024
        unitIndex += 1
    }

    if unitIndex == 0 {
        return "\(bytes) B"
    }
    return String(format: "%.1f %@", size, units[unitIndex])
}

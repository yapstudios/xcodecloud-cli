import Foundation

/// A single choice in a selection prompt
public struct Choice: Sendable {
    public let label: String
    public let value: String
    public let description: String?

    public init(label: String, value: String, description: String? = nil) {
        self.label = label
        self.value = value
        self.description = description
    }
}

/// Interactive arrow-key selection prompt
public enum SelectPrompt {

    /// Display a selection prompt and return the chosen item.
    /// Throws if the user quits (Ctrl+C or 'q').
    public static func run(prompt: String, choices: [Choice]) throws -> Choice {
        guard !choices.isEmpty else {
            throw SelectPromptError.noChoices
        }

        var selected = 0
        let totalLines = choices.count + 1 // prompt + choices

        TerminalUI.enableRawMode()
        TerminalUI.hideCursor()

        defer {
            TerminalUI.showCursor()
            TerminalUI.restoreTerminal()
        }

        // Reserve space so the terminal does all scrolling upfront.
        // Returns the absolute row where our block starts.
        let startRow = TerminalUI.reserveLines(totalLines)

        // Initial render
        renderFrame(prompt: prompt, choices: choices, selected: selected, startRow: startRow)

        while true {
            let key = TerminalUI.readKey()

            switch key {
            case .up:
                if selected > 0 { selected -= 1 }
            case .down:
                if selected < choices.count - 1 { selected += 1 }
            case .enter:
                // Jump to start, clear, print final selection
                TerminalUI.moveTo(row: startRow)
                TerminalUI.clearToEnd()
                let check = TerminalUI.cyan("?")
                // Use writeLine here because we're done — trailing \n is fine
                TerminalUI.writeLine("\(check) \(TerminalUI.bold(prompt)) \(TerminalUI.cyan(choices[selected].label))")
                return choices[selected]
            case .quit:
                TerminalUI.moveTo(row: startRow)
                TerminalUI.clearToEnd()
                throw SelectPromptError.cancelled
            case .other:
                continue
            }

            renderFrame(prompt: prompt, choices: choices, selected: selected, startRow: startRow)
        }
    }

    /// Build the entire frame as one string and write it atomically.
    /// No trailing newline — the cursor stays on the last content line,
    /// preventing any extra scroll that would invalidate startRow.
    private static func renderFrame(prompt: String, choices: [Choice], selected: Int, startRow: Int) {
        TerminalUI.moveTo(row: startRow)
        TerminalUI.clearToEnd()

        var lines = [String]()

        // Prompt line
        let arrow = TerminalUI.cyan("?")
        let hint = TerminalUI.dim("(arrow keys, enter to select)")
        lines.append("\(arrow) \(TerminalUI.bold(prompt)) \(hint)")

        // Choice lines
        for (i, choice) in choices.enumerated() {
            if i == selected {
                let cursor = TerminalUI.cyan("❯")
                var line = "\(cursor) \(TerminalUI.cyan(choice.label))"
                if let desc = choice.description {
                    line += " \(TerminalUI.dim(desc))"
                }
                lines.append(line)
            } else {
                var line = "  \(choice.label)"
                if let desc = choice.description {
                    line += " \(TerminalUI.dim(desc))"
                }
                lines.append(line)
            }
        }

        // Join with \r\n (carriage return + line feed) and NO trailing newline.
        // \r ensures we start at column 1 on each line.
        let frame = lines.joined(separator: "\r\n")
        TerminalUI.writeFlush(frame)
    }
}

public enum SelectPromptError: Error, CustomStringConvertible {
    case cancelled
    case noChoices

    public var description: String {
        switch self {
        case .cancelled: return "Selection cancelled"
        case .noChoices: return "No choices available"
        }
    }
}

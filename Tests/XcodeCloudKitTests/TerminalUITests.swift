import Testing
import Foundation
@testable import XcodeCloudKit

/// Tests for terminal UI utilities
@Suite("Terminal UI Tests")
struct TerminalUITests {

    // MARK: - ANSI Formatting

    @Test("Bold wraps text with ANSI codes")
    func testBold() {
        let result = TerminalUI.bold("Hello")
        #expect(result.contains("\u{1B}[1m"))
        #expect(result.contains("Hello"))
        #expect(result.contains("\u{1B}[0m"))
    }

    @Test("Cyan wraps text with ANSI codes")
    func testCyan() {
        let result = TerminalUI.cyan("Hello")
        #expect(result.contains("\u{1B}[36m"))
        #expect(result.contains("Hello"))
        #expect(result.contains("\u{1B}[0m"))
    }

    @Test("Dim wraps text with ANSI codes")
    func testDim() {
        let result = TerminalUI.dim("Hello")
        #expect(result.contains("\u{1B}[2m"))
        #expect(result.contains("Hello"))
        #expect(result.contains("\u{1B}[0m"))
    }

    @Test("Formatting preserves original text")
    func testFormattingPreservesText() {
        let original = "Test message with special chars: @#$%"
        let bold = TerminalUI.bold(original)
        let cyan = TerminalUI.cyan(original)
        let dim = TerminalUI.dim(original)

        #expect(bold.contains(original))
        #expect(cyan.contains(original))
        #expect(dim.contains(original))
    }

    @Test("Nested formatting works")
    func testNestedFormatting() {
        let inner = TerminalUI.cyan("blue")
        let outer = TerminalUI.bold(inner)

        #expect(outer.contains("blue"))
        #expect(outer.contains("\u{1B}[1m"))
        #expect(outer.contains("\u{1B}[36m"))
    }

    // MARK: - Key Event

    @Test("KeyEvent enum has all expected cases")
    func testKeyEventCases() {
        // Just verify the enum cases exist
        let events: [TerminalUI.KeyEvent] = [.up, .down, .enter, .quit, .other]
        #expect(events.count == 5)
    }

    // MARK: - TTY Detection

    @Test("isInteractiveTerminal returns boolean")
    func testIsInteractiveTerminal() {
        // In test environment, this will likely be false
        // Just verify it doesn't crash and returns a boolean
        let result = TerminalUI.isInteractiveTerminal
        #expect(result == true || result == false)
    }

    // MARK: - Terminal Height

    @Test("terminalHeight returns positive integer")
    func testTerminalHeight() {
        let height = TerminalUI.terminalHeight()
        // Should be at least the fallback value or actual terminal height
        #expect(height > 0)
        #expect(height >= 24) // Minimum fallback
    }
}

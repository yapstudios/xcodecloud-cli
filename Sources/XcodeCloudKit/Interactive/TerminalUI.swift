import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Low-level terminal utilities for interactive UI
public enum TerminalUI {

    // MARK: - Key Events

    public enum KeyEvent {
        case up
        case down
        case enter
        case quit
        case other
    }

    // MARK: - Raw Mode

    nonisolated(unsafe) private static var originalTermios = termios()
    nonisolated(unsafe) private static var isRawMode = false

    public static func enableRawMode() {
        guard !isRawMode else { return }
        tcgetattr(STDIN_FILENO, &originalTermios)
        var raw = originalTermios
        raw.c_lflag &= ~(UInt(ECHO | ICANON | ISIG))
        raw.c_cc.16 = 1  // VMIN
        raw.c_cc.17 = 0  // VTIME
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
        isRawMode = true
        installSignalHandler()
    }

    public static func restoreTerminal() {
        guard isRawMode else { return }
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTermios)
        isRawMode = false
        showCursor()
    }

    // MARK: - Signal Handling

    private static func installSignalHandler() {
        signal(SIGINT) { _ in
            TerminalUI.restoreTerminal()
            fputs("\n", stdout)
            exit(0)
        }
    }

    // MARK: - Key Reading

    public static func readKey() -> KeyEvent {
        var buf = [UInt8](repeating: 0, count: 3)
        let n = read(STDIN_FILENO, &buf, 3)

        if n == 1 {
            switch buf[0] {
            case 10, 13: return .enter       // Enter / Return
            case 3, 113: return .quit         // Ctrl+C or 'q'
            default: return .other
            }
        }

        if n == 3, buf[0] == 0x1B, buf[1] == 0x5B {
            switch buf[2] {
            case 0x41: return .up             // ESC [ A
            case 0x42: return .down           // ESC [ B
            default: return .other
            }
        }

        return .other
    }

    // MARK: - TTY Detection

    public static var isInteractiveTerminal: Bool {
        isatty(STDIN_FILENO) != 0 && isatty(STDOUT_FILENO) != 0
    }

    // MARK: - Terminal Size

    public static func terminalHeight() -> Int {
        var ws = winsize()
        if ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &ws) == 0 {
            return Int(ws.ws_row)
        }
        return 24 // fallback
    }

    // MARK: - Cursor Position

    /// Query the current cursor row (1-based). Must be in raw mode.
    public static func getCursorRow() -> Int {
        // Send cursor position query
        fputs("\u{1B}[6n", stdout)
        fflush(stdout)

        // Read response: ESC [ row ; col R
        var response = [UInt8]()
        while true {
            var c: UInt8 = 0
            let n = read(STDIN_FILENO, &c, 1)
            if n != 1 { break }
            response.append(c)
            if c == 0x52 { break } // 'R' terminates the response
        }

        // Parse "ESC[row;colR"
        let str = String(bytes: response, encoding: .ascii) ?? ""
        if let start = str.firstIndex(of: "["),
           let semi = str.firstIndex(of: ";") {
            let rowStr = str[str.index(after: start)..<semi]
            return Int(rowStr) ?? 1
        }
        return 1
    }

    /// Move cursor to an absolute row (1-based), column 1
    public static func moveTo(row: Int) {
        writeFlush("\u{1B}[\(row);1H")
    }

    /// Reserve N lines of space at the bottom of the terminal.
    /// Prints N newlines to force scrolling if needed, then moves back up.
    /// Returns the row where the block starts (1-based).
    public static func reserveLines(_ count: Int) -> Int {
        // Print empty lines to force scroll if near bottom
        for _ in 0..<count {
            writeFlush("\n")
        }
        // Move back up to where we started
        moveCursorUp(count)
        // Now query where we actually are
        return getCursorRow()
    }

    // MARK: - ANSI Helpers

    public static func hideCursor() {
        writeFlush("\u{1B}[?25l")
    }

    public static func showCursor() {
        writeFlush("\u{1B}[?25h")
    }

    public static func clearToEnd() {
        writeFlush("\u{1B}[J")
    }

    public static func clearLine() {
        writeFlush("\r\u{1B}[2K")
    }

    public static func moveCursorUp(_ n: Int) {
        if n > 0 {
            writeFlush("\u{1B}[\(n)A")
        }
    }

    /// Write a line to stdout with newline, flushing immediately
    public static func writeLine(_ text: String) {
        writeFlush(text + "\n")
    }

    /// Write to stdout without newline, flushing immediately
    public static func writeFlush(_ text: String) {
        fputs(text, stdout)
        fflush(stdout)
    }

    public static func bold(_ text: String) -> String {
        "\u{1B}[1m\(text)\u{1B}[0m"
    }

    public static func cyan(_ text: String) -> String {
        "\u{1B}[36m\(text)\u{1B}[0m"
    }

    public static func dim(_ text: String) -> String {
        "\u{1B}[2m\(text)\u{1B}[0m"
    }
}

import Foundation

/// Strips ANSI escape sequences from terminal output.
///
/// This is a simplified replacement for the SwiftTerm-based renderer.
/// It strips common escape sequences rather than fully emulating a terminal.
/// Sufficient for parsing `claude /usage` output which uses basic color codes.
public final class TerminalRenderer {
    public init(cols: Int = 160, rows: Int = 50) {}

    /// Strips ANSI escape sequences from raw terminal output.
    ///
    /// - Parameter raw: Raw terminal output containing ANSI escape sequences
    /// - Returns: Text with escape sequences removed
    public func render(_ raw: String) -> String {
        // Strip ESC[ ... m  (SGR color/style codes)
        // Strip ESC[ ... H/J/K  (cursor movement and clear codes)
        // Strip ESC[ ... A/B/C/D  (cursor directional movement)
        // Strip ESC(B and similar single-char commands
        var result = raw

        // Remove ESC followed by [ and parameters up to a final letter
        // Pattern: \x1B [ params letter
        if let regex = try? NSRegularExpression(pattern: "\u{1B}\\[[0-9;]*[A-Za-z]") {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }

        // Remove remaining standalone ESC sequences (e.g. ESC(B, ESC=)
        if let regex = try? NSRegularExpression(pattern: "\u{1B}[^\\[\\r\\n]") {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }

        // Remove bare ESC characters
        result = result.replacingOccurrences(of: "\u{1B}", with: "")

        // Remove carriage returns
        result = result.replacingOccurrences(of: "\r", with: "")

        return result
    }
}

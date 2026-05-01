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
        // Translate cursor-right (`ESC[NC`) into N spaces so word fragments
        // like "Curre[1Ct[1Csession" become "Current session" rather than
        // "CurreCtCsession". Other CSI sequences (colors, clears, other cursor
        // moves) are stripped without substitution.
        var result = raw

        // ESC[NC → N spaces. Default count when N is omitted is 1.
        if let regex = try? NSRegularExpression(pattern: "\u{1B}\\[(\\d*)C") {
            let nsResult = result as NSString
            let matches = regex.matches(in: result, range: NSRange(location: 0, length: nsResult.length))
            var rebuilt = ""
            var lastEnd = 0
            for match in matches {
                let r = match.range
                rebuilt += nsResult.substring(with: NSRange(location: lastEnd, length: r.location - lastEnd))
                let countRange = match.range(at: 1)
                let count: Int = {
                    guard countRange.length > 0 else { return 1 }
                    return Int(nsResult.substring(with: countRange)) ?? 1
                }()
                rebuilt += String(repeating: " ", count: max(0, count))
                lastEnd = r.location + r.length
            }
            rebuilt += nsResult.substring(from: lastEnd)
            result = rebuilt
        }

        // Strip remaining CSI sequences: ESC[ params final-letter (e.g. SGR `m`,
        // cursor moves A/B/D/E/F/G/H, clears J/K, scroll regions, etc.)
        if let regex = try? NSRegularExpression(pattern: "\u{1B}\\[[0-9;?]*[A-Za-z]") {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }

        // Strip OSC sequences: ESC ] ... BEL (terminal title etc.)
        if let regex = try? NSRegularExpression(pattern: "\u{1B}\\][^\u{07}]*\u{07}") {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }

        // Strip remaining 2-char ESC sequences (e.g. ESC(B, ESC=, ESC>)
        if let regex = try? NSRegularExpression(pattern: "\u{1B}[^\\[\\]]") {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }

        // Remove bare ESC characters and carriage returns
        result = result.replacingOccurrences(of: "\u{1B}", with: "")
        result = result.replacingOccurrences(of: "\r", with: "")

        return result
    }
}

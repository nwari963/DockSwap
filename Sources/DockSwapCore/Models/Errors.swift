import Foundation

/// CLI/engine errors with the exit-code contract from ticket 004.
public enum DockSwapError: Error, CustomStringConvertible, Equatable {
    case invalidName(String)
    case presetNotFound(String)
    case dockutilMissing
    case invalidPreset(String)
    case dockutilFailed(output: String, exitCode: Int)
    case io(String)

    public var exitCode: Int32 {
        switch self {
        case .invalidName: return 1
        case .presetNotFound: return 2
        case .dockutilMissing: return 3
        case .invalidPreset: return 4
        case .dockutilFailed: return 5
        case .io: return 6
        }
    }

    public var description: String {
        switch self {
        case .invalidName(let name):
            return "invalid preset name '\(name)' (must match [A-Za-z0-9][A-Za-z0-9._-]*)"
        case .presetNotFound(let name):
            return "preset '\(name)' not found"
        case .dockutilMissing:
            return "dockutil not found — install with `brew install dockutil`"
        case .invalidPreset(let detail):
            return "invalid preset: \(detail)"
        case .dockutilFailed(let output, let exitCode):
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "dockutil failed (exit \(exitCode))" : trimmed
        case .io(let detail):
            return detail
        }
    }
}

/// Preset names are a single filename token: no `/`, no leading `.`.
public func validatePresetName(_ name: String) throws {
    let pattern = "^[A-Za-z0-9][A-Za-z0-9._-]*$"
    let range = NSRange(name.startIndex..., in: name)
    let re = try! NSRegularExpression(pattern: pattern)
    guard re.firstMatch(in: name, range: range) != nil else {
        throw DockSwapError.invalidName(name)
    }
}

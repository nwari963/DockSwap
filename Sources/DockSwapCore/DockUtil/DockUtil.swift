import Foundation

/// Protocol for mocking `dockutil` in tests.
public protocol DockUtilExecuting {
    func run(_ args: [String]) throws -> String
}

/// Live `dockutil` executor.
public struct DockUtil: DockUtilExecuting {
    public let path: String

    public init(path: String = "dockutil") {
        self.path = path
    }

    public func run(_ args: [String]) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser

        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe

        try p.run()
        p.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if p.terminationStatus != 0 {
            throw DockUtilError.nonzeroExit(output: output, exitCode: Int(p.terminationStatus))
        }
        return output
    }
}

/// Errors from `dockutil`.
public enum DockUtilError: Error {
    case nonzeroExit(output: String, exitCode: Int)
}

/// Parse `dockutil --list` output into items.
public func parseDockList(_ output: String) -> [DockListItem] {
    output
        .components(separatedBy: .newlines)
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .compactMap { DockListItem(line: $0) }
        .filter { $0.section != "recent-apps" }
}

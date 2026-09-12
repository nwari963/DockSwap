import Foundation

/// Protocol for mocking `dockutil` in tests.
public protocol DockUtilExecuting {
    func run(_ args: [String]) throws -> String
}

/// Live `dockutil` executor. Path: `$DOCKSWAP_DOCKUTIL_PATH` → PATH (ticket 002).
public struct DockUtil: DockUtilExecuting {
    public let path: String

    public init(path: String) {
        self.path = path
    }

    /// Resolve binary and refuse dockutil < 3.0.
    public static func resolved() throws -> DockUtil {
        let path = try resolvePath()
        let util = DockUtil(path: path)
        let output = try util.run(["--version"])
        guard let version = parseDockutilVersion(output), version.major >= 3 else {
            throw DockSwapError.dockutilMissing
        }
        return util
    }

    public func run(_ args: [String]) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser

        let outPipe = Pipe()
        let errPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = errPipe

        do {
            try p.run()
        } catch {
            throw DockSwapError.dockutilMissing
        }
        p.waitUntilExit()

        let stdout = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        if p.terminationStatus != 0 {
            throw DockSwapError.dockutilFailed(
                command: args,
                output: stderr.isEmpty ? stdout : stderr,
                exitCode: Int(p.terminationStatus)
            )
        }
        return stdout
    }
}

func resolvePath() throws -> String {
    if let env = ProcessInfo.processInfo.environment["DOCKSWAP_DOCKUTIL_PATH"], !env.isEmpty {
        if FileManager.default.isExecutableFile(atPath: env) {
            return env
        }
        throw DockSwapError.dockutilMissing
    }
    if let found = findExecutable("dockutil") {
        return found
    }
    throw DockSwapError.dockutilMissing
}

func findExecutable(_ name: String) -> String? {
    if name.hasPrefix("/"), FileManager.default.isExecutableFile(atPath: name) {
        return name
    }
    let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
    for dir in path.split(separator: ":") {
        let candidate = "\(dir)/\(name)"
        if FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }
    }
    return nil
}

struct DockutilVersion {
    let major: Int
}

/// First semver-ish token; accepts `3.1.3` and `dockutil 3.1.3`.
func parseDockutilVersion(_ output: String) -> DockutilVersion? {
    let re = try! NSRegularExpression(pattern: "\\d+\\.\\d+(?:\\.\\d+)?")
    let ns = output as NSString
    guard let match = re.firstMatch(in: output, range: NSRange(location: 0, length: ns.length)) else {
        return nil
    }
    let token = ns.substring(with: match.range)
    let major = Int(token.split(separator: ".").first ?? "") ?? 0
    return DockutilVersion(major: major)
}

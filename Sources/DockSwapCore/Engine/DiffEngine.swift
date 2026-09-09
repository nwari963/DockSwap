import Foundation

// MARK: - Apply

public struct DockDiffEngine {
    public let dockUtil: DockUtilExecuting

    public init(dockUtil: DockUtilExecuting = DockUtil(path: "")) {
        self.dockUtil = dockUtil
    }

    public func apply(_ preset: DockPreset) throws -> Bool {
        let current = try captureCurrentPreset()
        guard !isApplied(preset, to: current) else { return false }

        let (removes, adds) = diff(preset, from: current)
        guard !removes.isEmpty || !adds.isEmpty else { return false }

        var args: [String] = []
        for item in removes { args.append(contentsOf: item.removeArgs) }
        for item in adds { args.append(contentsOf: item.addArgs) }

        if !args.isEmpty { _ = try dockUtil.run(args) }
        return true
    }

    public func captureCurrentPreset() throws -> DockPreset {
        captureLiveDock(from: try dockUtil.run(["--list"]), name: "live")
    }
}

// MARK: - Diffing

public func diff(_ preset: DockPreset, from current: DockPreset) -> ([DiffItem], [DiffItem]) {
    var removes: [DiffItem] = []
    var adds: [DiffItem] = []

    for item in current.apps {
        if item.isSpacer { continue }          // spacers are positional; never remove (003)
        let sectionName = "apps"
        if !contains(item, in: preset, section: sectionName) {
            removes.append(DiffItem(item: item, section: sectionName))
        }
    }
    for item in current.others {
        if item.isSpacer { continue }
        let sectionName = "others"
        if !contains(item, in: preset, section: sectionName) {
            removes.append(DiffItem(item: item, section: sectionName))
        }
    }

    for item in preset.apps {
        if item.isSpacer { continue }          // add spacers positionally only via adds of other items (ponytail: simple order handling)
        let sectionName = "apps"
        if !contains(item, in: current, section: sectionName) {
            adds.append(DiffItem(item: item, section: sectionName))
        }
    }
    for item in preset.others {
        if item.isSpacer { continue }
        let sectionName = "others"
        if !contains(item, in: current, section: sectionName) {
            adds.append(DiffItem(item: item, section: sectionName))
        }
    }

    return (removes, adds)
}

public func isApplied(_ preset: DockPreset, to current: DockPreset) -> Bool {
    let (removes, adds) = diff(preset, from: current)
    return removes.isEmpty && adds.isEmpty
}

public struct DiffItem {
    public let item: DockItem
    public let section: String

    public var removeArgs: [String] {
        switch item {
        case .app(let app):
            if let bundleId = app.identity.bundleId { return ["--remove", bundleId, "--section", section] }
            else if let path = app.identity.path { return ["--remove", path, "--section", section] }
            else { return [] }
        case .folder(let folder): return ["--remove", folder.path, "--section", section]
        case .url(let url): return ["--remove", url.url, "--section", section]
        case .spacer: return []
        }
    }

    public var addArgs: [String] {
        switch item {
        case .app(let app):
            if let path = app.identity.path { return ["--add", path, "--section", section] }
            else { return [] }
        case .folder(let folder): return ["--add", folder.path, "--section", section]
        case .url(let url): return ["--add", url.url, "--section", section]
        case .spacer: return ["--add", "spacer", "--section", section]
        }
    }
}

// MARK: - Identity helpers

private func contains(_ item: DockItem, in preset: DockPreset, section sectionName: String) -> Bool {
    let candidates = sectionName == "others" ? preset.others : preset.apps
    if item.isSpacer { return candidates.contains(where: { $0.isSpacer }) }
    return candidates.contains(where: { $0.matches(item) })
}

private func section(for item: DockItem, in preset: DockPreset) -> String {
    if preset.apps.contains(where: { $0.matches(item) }) { return "apps" }
    if preset.others.contains(where: { $0.matches(item) }) { return "others" }
    return "apps"
}

// MARK: - DockItem extensions

private extension DockItem {
    var isSpacer: Bool {
        if case .spacer = self { return true }
        return false
    }

    func matches(_ other: DockItem) -> Bool {
        switch (self, other) {
        case (.app(let lhs), .app(let rhs)):
            return lhs.identity.bundleId == rhs.identity.bundleId || lhs.identity.path?.canonicalized == rhs.identity.path?.canonicalized
        case (.folder(let lhs), .folder(let rhs)):
            return lhs.path.canonicalized == rhs.path.canonicalized
        case (.url(let lhs), .url(let rhs)):
            return lhs.url == rhs.url
        case (.spacer, .spacer):
            return true
        default:
            return false
        }
    }
}

// MARK: - String canonicalization

private extension String {
    var canonicalized: String {
        var path = self
        if path.hasPrefix("~") { path = (path as NSString).expandingTildeInPath }
        if path.hasPrefix("file://") { path = String(path.dropFirst("file://".count)) }
        if path.hasSuffix("/") { path = String(path.dropLast()) }
        let resolved = (path as NSString).resolvingSymlinksInPath
        path = resolved
        if path.hasPrefix("/System/Applications/"), FileManager.default.fileExists(atPath: "/Applications/" + String(path.dropFirst("/System/Applications/".count))) {
            path = "/Applications/" + String(path.dropFirst("/System/Applications/".count))
        } else if path.hasPrefix("/Applications/"), FileManager.default.fileExists(atPath: "/System/Applications/" + String(path.dropFirst("/Applications/".count))) {
            path = "/System/Applications/" + String(path.dropFirst("/Applications/".count))
        }
        return path
    }
}

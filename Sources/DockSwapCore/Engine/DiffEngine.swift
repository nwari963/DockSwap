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
        args.append(contentsOf: addArgs(for: preset.apps, section: "apps", current: current))
        args.append(contentsOf: addArgs(for: preset.others, section: "others", current: current))

        if !args.isEmpty { _ = try dockUtil.run(args) }
        return true
    }

    public func captureCurrentPreset() throws -> DockPreset {
        captureLiveDock(from: try dockUtil.run(["--list"]), name: "live")
    }
}

// MARK: - Anchored add args (ticket 003: preserve preset order)

/// dockutil's `--position after` needs the *previous* item; the previous
/// preset item may itself be a new add earlier in the batch, so we need the
/// current dock's identity mapping **plus** the already-emitted prior adds.
/// dockutil processes `--add` sequentially; anchoring to a just-added item works.
private func addArgs(for items: [DockItem], section: String, current: DockPreset) -> [String] {
    var result: [String] = []
    var present = Set(current.items(in: section).compactMap { $0.dockutilAnchor })
    for item in items {
        // Spacers: use their preset position for anchoring
        if case .spacer = item {
            if let prev = presenterAnchor(before: item, in: items) {
                result.append(contentsOf: ["--add", "spacer", "--section", section, "--position", "after", prev])
            } else {
                result.append(contentsOf: ["--add", "spacer", "--section", section])
            }
            continue
        }
        if present.contains(item.dockutilAnchor ?? "") { continue } // already in dock
        var args = ["--add", item.dockutilAnchor ?? "", "--section", section]
        if let prev = presenterAnchor(before: item, in: items) {
            args.append(contentsOf: ["--position", "after", prev])
        } else {
            args.append(contentsOf: ["--position", "beginning"])
        }
        result.append(contentsOf: args)
        if let anchor = item.dockutilAnchor { present.insert(anchor) }
    }
    return result
}

/// The identity anchor of the preset item immediately before `item` (preset order),
/// if that predecessor is either already in the current dock or added earlier here.
private func presenterAnchor(before target: DockItem, in items: [DockItem]) -> String? {
    guard let idx = items.firstIndex(where: { $0 == target }) else { return nil }
    guard idx > 0 else { return nil }
    return items[idx - 1].dockutilAnchor
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

// MARK: - DockPreset extensions

extension DockPreset {
    func items(in section: String) -> [DockItem] {
        section == "others" ? others : apps
    }

    /// The dockutil anchor for a preset item: bundleId (apps) else path (apps/folders)
    /// else full url (URLs). Never the label — labels are volatile (ticket 003§4).
    func anchor(for item: DockItem) -> String? {
        switch item {
        case .app(let app): return app.identity.bundleId ?? app.identity.path
        case .folder(let folder): return folder.path
        case .url(let url): return url.url
        case .spacer: return nil
        }
    }
}

// MARK: - DockItem extensions

private extension DockItem {
    var isSpacer: Bool {
        if case .spacer = self { return true }
        return false
    }

    var dockutilAnchor: String? {
        switch self {
        case .app(let app): return app.identity.bundleId ?? app.identity.path
        case .folder(let folder): return folder.path
        case .url(let url): return url.url
        case .spacer: return nil
        }
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

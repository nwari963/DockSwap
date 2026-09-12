import Foundation

// MARK: - Apply

public struct DockDiffEngine {
    public let dockUtil: DockUtilExecuting

    public init(dockUtil: DockUtilExecuting = DockUtil(path: "")) {
        self.dockUtil = dockUtil
    }

    /// Applies `preset`. Returns `nil` when already applied (no-op, matches
    /// ticket 003's short-circuit); otherwise the counts for the human-output
    /// message (ticket 004: "Switched to '<name>' (N removed, M added).").
    public func apply(_ preset: DockPreset) throws -> (removed: Int, added: Int)? {
        let current = try captureCurrentPreset()
        guard !isApplied(preset, to: current) else { return nil }

        let (removes, adds) = diff(preset, from: current)
        guard !removes.isEmpty || !adds.isEmpty else { return nil }

        var args: [String] = []
        for item in removes { args.append(contentsOf: item.removeArgs) }
        args.append(contentsOf: addArgs(for: preset.apps, adds: adds, section: "apps", current: current))
        args.append(contentsOf: addArgs(for: preset.others, adds: adds, section: "others", current: current))

        if !args.isEmpty { _ = try dockUtil.run(args) }
        return (removes.count, adds.count)
    }

    public func captureCurrentPreset() throws -> DockPreset {
        captureLiveDock(
            from: try dockUtil.run(["--list"]),
            name: "live",
            dockutilVersion: try dockUtil.run(["--version"]).trimmingCharacters(in: .whitespacesAndNewlines),
            macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString
        )
    }
}

// MARK: - Anchored add args (ticket 003: preserve preset order)

/// dockutil's `--position after` needs the *previous* item; the previous
/// preset item may itself be a new add earlier in the batch, so we need the
/// current dock's identity mapping **plus** the already-emitted prior adds.
/// dockutil processes `--add` sequentially; anchoring to a just-added item works.
private func addArgs(for items: [DockItem], adds: [DiffItem], section: String, current: DockPreset) -> [String] {
    var result: [String] = []
    let toAdd = adds.filter { $0.section == section }.map { $0.item }
    var currentSpacerCount = current.items(in: section).filter { $0.isSpacer }.count
    for item in items {
        // Spacers carry no identity (003 rule 5): treat the current dock's existing
        // spacers as already satisfying the earliest preset slots, and add only the
        // excess, so a switch with other diffs doesn't duplicate spacers each time.
        if case .spacer = item {
            if currentSpacerCount > 0 {
                currentSpacerCount -= 1
                continue
            }
            if let prev = presenterAnchor(before: item, in: items) {
                result.append(contentsOf: ["--add", "spacer", "--section", section, "--position", "after", prev])
            } else {
                result.append(contentsOf: ["--add", "spacer", "--section", section])
            }
            continue
        }
        guard toAdd.contains(item) else { continue } // already in dock (identity-matched by diff())
        var args = DiffItem(item: item, section: section).addArgs
        if let prev = presenterAnchor(before: item, in: items) {
            args.append(contentsOf: ["--position", "after", prev])
        } else {
            args.append(contentsOf: ["--position", "beginning"])
        }
        result.append(contentsOf: args)
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

// MARK: - DockPreset extensions

extension DockPreset {
    func items(in section: String) -> [DockItem] {
        section == "others" ? others : apps
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
            // 003 rule 1: match on bundleId only when both sides have one; a bare
            // `bundleId == bundleId` would let two different path-only apps match
            // via `nil == nil`, so fall through to path comparison otherwise.
            if let lhsID = lhs.identity.bundleId, let rhsID = rhs.identity.bundleId {
                return lhsID == rhsID
            }
            return lhs.identity.path?.canonicalized == rhs.identity.path?.canonicalized
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

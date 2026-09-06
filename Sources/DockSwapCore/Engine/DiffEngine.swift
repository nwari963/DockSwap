import Foundation

/// Diff engine for applying presets to the live dock.
public struct DockDiffEngine {
    public let dockUtil: DockUtilExecuting

    public init(dockUtil: DockUtilExecuting = DockUtil()) {
        self.dockUtil = dockUtil
    }

    /// Apply a preset to the live dock.
    /// - Returns: true if the dock was changed, false if already applied.
    public func apply(_ preset: DockPreset) throws -> Bool {
        let current = try captureLiveDock()
        guard !preset.isApplied(to: current) else { return false }

        let (removes, adds) = preset.diff(from: current)
        guard !removes.isEmpty || !adds.isEmpty else { return false }

        var args: [String] = []
        // Remove first, then add
        for item in removes {
            args.append(contentsOf: item.removeArgs)
        }
        for item in adds {
            args.append(contentsOf: item.addArgs)
        }

        if !args.isEmpty {
            try dockUtil.run(args)
        }
        return true
    }

    /// Capture the live dock using `dockutil --list`.
    public func captureLiveDock() throws -> DockPreset {
        let output = try dockUtil.run(["--list"])
        return captureLiveDock(from: output, name: "live")
    }
}

// MARK: - Diffing

/// Diff a preset against the live dock.
/// - Returns: (removals, additions)
public func diff(from current: DockPreset) -> ([DiffItem], [DiffItem]) {
    var removes: [DiffItem] = []
    var adds: [DiffItem] = []

    // Removals: items in current not in preset
    for item in current.apps + current.others {
        if !preset.contains(item) {
            removes.append(DiffItem(item: item, section: item.section(in: current)))
        }
    }

    // Additions: items in preset not in current
    for item in preset.apps + preset.others {
        if !current.contains(item) {
            adds.append(DiffItem(item: item, section: item.section(in: preset)))
        }
    }

    return (removes, adds)
}

/// Check if a preset is already applied to the live dock.
public func isApplied(to current: DockPreset) -> Bool {
    let (removes, adds) = diff(from: current)
    return removes.isEmpty && adds.isEmpty
}

/// A diff item with its section.
public struct DiffItem {
    public let item: DockItem
    public let section: String

    public var removeArgs: [String] {
        switch item {
        case .app(let app):
            if let bundleId = app.identity.bundleId {
                return ["--remove", bundleId, "--section", section]
            } else if let path = app.identity.path {
                return ["--remove", path, "--section", section]
            } else {
                return []
            }
        case .folder(let folder):
            return ["--remove", folder.path, "--section", section]
        case .url(let url):
            return ["--remove", url.url, "--section", section]
        case .spacer:
            return []
        }
    }

    public var addArgs: [String] {
        switch item {
        case .app(let app):
            if let path = app.identity.path {
                return ["--add", path, "--section", section]
            } else {
                return []
            }
        case .folder(let folder):
            return ["--add", folder.path, "--section", section]
        case .url(let url):
            return ["--add", url.url, "--section", section]
        case .spacer:
            return ["--add", "spacer", "--section", section]
        }
    }
}

// MARK: - Identity matching

/// Check if a preset contains an item.
public func contains(_ item: DockItem) -> Bool {
    switch item {
    case .app(let app):
        return apps.contains(where: { $0.matches(app) }) || others.contains(where: { $0.matches(app) })
    case .folder(let folder):
        return apps.contains(where: { $0.matches(folder) }) || others.contains(where: { $0.matches(folder) })
    case .url(let url):
        return apps.contains(where: { $0.matches(url) }) || others.contains(where: { $0.matches(url) })
    case .spacer:
        return apps.contains(where: { $0.isSpacer }) || others.contains(where: { $0.isSpacer })
    }
}

/// Check if an item matches another item.
public func matches(_ other: DockItem) -> Bool {
    switch (self, other) {
    case (.app(let lhs), .app(let rhs)):
        return lhs.identity.bundleId == rhs.identity.bundleId
            || lhs.identity.path?.canonicalized == rhs.identity.path?.canonicalized
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

/// Canonicalize a path for comparison.
public var canonicalized: String {
    var path = self
    // Expand ~
    if path.hasPrefix("~") {
        path = (path as NSString).expandingTildeInPath
    }
    // Strip file://
    if path.hasPrefix("file://") {
        path = String(path.dropFirst("file://".count))
    }
    // Strip trailing /
    if path.hasSuffix("/") {
        path = String(path.dropLast())
    }
    // Resolve symlinks
    if let resolved = (path as NSString).resolvingSymlinksInPath {
        path = resolved
    }
    // Try /System/Applications ↔ /Applications
    if path.hasPrefix("/System/Applications/") {
        let alt = "/Applications/" + String(path.dropFirst("/System/Applications/".count))
        if FileManager.default.fileExists(atPath: alt) {
            path = alt
        }
    } else if path.hasPrefix("/Applications/") {
        let alt = "/System/Applications/" + String(path.dropFirst("/Applications/".count))
        if FileManager.default.fileExists(atPath: alt) {
            path = alt
        }
    }
    return path
}

/// Get the section for an item.
public func section(in preset: DockPreset) -> String {
    if preset.apps.contains(where: { $0.matches(self) }) {
        return "apps"
    } else if preset.others.contains(where: { $0.matches(self) }) {
        return "others"
    } else {
        return "apps"
    }
}

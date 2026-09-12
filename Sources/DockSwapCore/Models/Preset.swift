import Foundation

// MARK: - Preset schema (ticket 001)

/// The current preset schema version.
public let currentSchemaVersion = 1

/// A single dock preset.
public struct DockPreset: Codable, Equatable {
    public var name: String
    public var schemaVersion: Int
    public var createdAt: String
    public var updatedAt: String
    public var dockutilVersion: String?
    public var macOSVersion: String?
    public var apps: [DockItem]
    public var others: [DockItem]

    public init(
        name: String,
        schemaVersion: Int = currentSchemaVersion,
        createdAt: String,
        updatedAt: String,
        dockutilVersion: String? = nil,
        macOSVersion: String? = nil,
        apps: [DockItem] = [],
        others: [DockItem] = []
    ) {
        self.name = name
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.dockutilVersion = dockutilVersion
        self.macOSVersion = macOSVersion
        self.apps = apps
        self.others = others
    }
}

/// A dock item discriminated by `type`.
public enum DockItem: Codable, Equatable {
    /// JSON representation matches ticket 001 (discriminated objects).
    case app(AppItemPayload)
    case folder(FolderItemPayload)
    case url(URLItemPayload)
    case spacer

    /// Short human-readable label for the dry-run report.
    public var description: String {
        switch self {
        case .app(let app): return app.identity.bundleId ?? app.identity.path ?? "app"
        case .folder(let folder): return folder.path
        case .url(let url): return url.url
        case .spacer: return "spacer"
        }
    }

    public enum CodingKeys: String, CodingKey {
        case type, identity, path, view, display, sort, title, url
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "app":    self = .app(try AppItemPayload(from: decoder))
        case "folder": self = .folder(try FolderItemPayload(from: decoder))
        case "url":    self = .url(try URLItemPayload(from: decoder))
        case "spacer": self = .spacer
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "unknown type \(type)"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .app(let item):
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode("app", forKey: .type)
            try c.encode(item.identity, forKey: .identity)
        case .folder(let item):
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode("folder", forKey: .type)
            try c.encode(item.path, forKey: .path)
            if let v = item.view { try c.encode(v, forKey: .view) }
            if let d = item.display { try c.encode(d, forKey: .display) }
            if let s = item.sort { try c.encode(s, forKey: .sort) }
        case .url(let item):
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode("url", forKey: .type)
            try c.encode(item.title, forKey: .title)
            try c.encode(item.url, forKey: .url)
        case .spacer:
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode("spacer", forKey: .type)
        }
    }
}

/// Identity for app items.
public struct AppIdentity: Codable, Equatable {
    public var bundleId: String?
    public var path: String?

    public init(bundleId: String? = nil, path: String? = nil) {
        self.bundleId = bundleId
        self.path = path
    }
}

// MARK: - Codable item payloads (JSON mirrors ticket 001)

public struct AppItemPayload: Codable, Equatable {
    public var identity: AppIdentity
    public init(identity: AppIdentity) { self.identity = identity }
}

public struct FolderItemPayload: Codable, Equatable {
    public var path: String
    public var view: String?
    public var display: String?
    public var sort: String?

    public init(path: String, view: String? = nil, display: String? = nil, sort: String? = nil) {
        self.path = path
        self.view = view
        self.display = display
        self.sort = sort
    }
}

public struct URLItemPayload: Codable, Equatable {
    public var title: String
    public var url: String

    public init(title: String, url: String) {
        self.title = title
        self.url = url
    }
}

// MARK: - Parsing dockutil --list output

/// A row from `dockutil --list`.
public struct DockListItem: Equatable {
    public var label: String
    public var url: String
    public var section: String
    public var plistPath: String
    public var bundleId: String
    /// nil if recent-apps or otherwise empty
    public var isSpacerRow: Bool {
        label.isEmpty && url.isEmpty && bundleId.isEmpty
    }

    /// Initialize from a tab-separated `dockutil --list` line.
    public init?(line: String) {
        let cols = line.components(separatedBy: "\t")
        guard cols.count >= 5 else { return nil }
        label = cols[0].trimmingCharacters(in: .whitespacesAndNewlines)
        url = cols[1].trimmingCharacters(in: .whitespacesAndNewlines)
        section = cols[2].trimmingCharacters(in: .whitespacesAndNewlines)
        plistPath = cols[3].trimmingCharacters(in: .whitespacesAndNewlines)
        bundleId = cols[4].trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Parse full `dockutil --list` output into items, filtering recent-apps rows.
public func parseDockList(_ output: String) -> [DockListItem] {
    output
        .components(separatedBy: .newlines)
        .compactMap { DockListItem(line: $0) }
        .filter { $0.section != "recent-apps" }
}

// MARK: - Capture fixture (live dock recorded 2026-09-06)

/// Capture the live dock using `dockutil --list` and convert to a preset.
/// Section names from dockutil 3.1.3 come back as `persistentApps` / `persistentOthers`.
public func captureLiveDock(from output: String, name: String, dockutilVersion: String? = nil, macOSVersion: String? = nil) -> DockPreset {
    let items = parseDockList(output)
    var apps: [DockItem] = []
    var others: [DockItem] = []

    let iso8601: () -> String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        f.timeZone = TimeZone(abbreviation: "UTC")
        return f.string(from: Date())
    }
    let now = iso8601()

    for item in items {
        if item.isSpacerRow {
            let targetSection = item.section.lowercased()
            if targetSection == "persistentothers" { others.append(.spacer) } else { apps.append(.spacer) }
            continue
        }

        let section = item.section.lowercased()
        // Determine item type
        let path = item.url

        // An app: URL points at a .app bundle, OR a bundleId is present.
        let isApp = path.hasSuffix(".app/") || !item.bundleId.isEmpty
        if isApp {
            let id = AppIdentity(
                bundleId: item.bundleId.isEmpty ? nil : item.bundleId,
                path: path.isEmpty ? nil : String(path.dropFirst("file://".count).dropLast(1).removingPercentEncoding ?? "")
            )
            let app = AppItemPayload(identity: id)
            section.contains("others") ? others.append(.app(app)) : apps.append(.app(app))
        } else if path.hasPrefix("file://") {
            // Directory rows (stacks/folders): classify by scheme, not by a
            // trailing "/" — a plain https:// URL tile very commonly ends in
            // "/" too and isn't a folder, so that heuristic misclassified it
            // as one and corrupted its url by stripping a "file://"-length
            // prefix that was never there (found via manual QA).
            let folder = FolderItemPayload(path: String(path.dropFirst("file://".count).dropLast(1).removingPercentEncoding ?? ""))
            section.contains("others") ? others.append(.folder(folder)) : apps.append(.folder(folder))
        } else if item.bundleId.isEmpty && ["spacer", "small-spacer", "flex-spacer"].contains(item.label) {
            // Real dockutil 3.1.3 represents an added spacer with a literal
            // "spacer"-family label and a synthetic <home>/spacer url, not
            // the fully-empty row isSpacerRow (and ticket 001's research)
            // assumed — confirmed by round-tripping a real spacer through
            // capture. Without this, a captured spacer became a bogus URL
            // item, eligible for removal, violating ticket 003 rule 5.
            section.contains("others") ? others.append(.spacer) : apps.append(.spacer)
        } else {
            // URL tile: keep the url exactly as reported, no stripping.
            let urlItem = URLItemPayload(title: item.label, url: path)
            section.contains("others") ? others.append(.url(urlItem)) : apps.append(.url(urlItem))
        }
    }

    return DockPreset(
        name: name,
        schemaVersion: currentSchemaVersion,
        createdAt: now,
        updatedAt: now,
        dockutilVersion: dockutilVersion,
        macOSVersion: macOSVersion,
        apps: apps,
        others: others
    )
}

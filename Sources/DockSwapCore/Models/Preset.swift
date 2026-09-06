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
    case app(AppItem)
    case folder(FolderItem)
    case url(URLItem)
    case spacer

    public enum CodingKeys: String, CodingKey {
        case type, identity, path, view, display, sort, title, url
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "app":    self = .app(try AppItem(from: decoder))
        case "folder": self = .folder(try FolderItem(from: decoder))
        case "url":    self = .url(try URLItem(from: decoder))
        case "spacer": self = .spacer
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "unknown type \(type)"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .app(var item):
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode("app", forKey: .type)
            try c.encode(item.identity.bundleId, forKey: .identity)
            try c.encode(item.identity.path, forKey: .path)
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
            var c = encoder.singleValueContainer()
            try c.encode("spacer")
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

public struct AppItem: Codable, Equatable {
    public var identity: AppIdentity
    public init(identity: AppIdentity) { self.identity = identity }
}

public struct FolderItem: Codable, Equatable {
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

public struct URLItem: Codable, Equatable {
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
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .compactMap { DockListItem(line: $0) }
        .filter { $0.section != "recent-apps" }
}

// MARK: - Capture fixture (live dock recorded 2026-09-06)

/// Capture the live dock using `dockutil --list` and convert to a preset.
/// Section names from dockutil 3.1.3 come back as `persistentApps` / `persistentOthers`.
public func captureLiveDock(from output: String, name: String) -> DockPreset {
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
            item.section == "persistentOthers" ? others.append(.spacer) : apps.append(.spacer)
            continue
        }

        let section = item.section.lowercased()
        // Determine item type
        let url = item.url
        let isApp = url.hasSuffix(".app/")
        if isApp {
            let id = AppIdentity(
                bundleId: item.bundleId.isEmpty ? nil : item.bundleId,
                path: url.isEmpty ? nil : String(url.dropFirst("file://".count).dropLast(1).removingPercentEncoding ?? "")
            )
            let app = AppItem(identity: id)
            section.contains("others") ? others.append(.app(app)) : apps.append(.app(app))
        } else {
            let urlItem = URLItem(title: item.label, url: url)
            section.contains("others") ? others.append(.url(urlItem)) : apps.append(.url(urlItem))
        }
    }

    return DockPreset(
        name: name,
        schemaVersion: currentSchemaVersion,
        createdAt: now,
        updatedAt: now,
        dockutilVersion: "3.1.3",
        macOSVersion: "26.5",
        apps: apps,
        others: others
    )
}

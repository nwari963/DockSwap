import Foundation

/// Owns the filesystem side of a DockSwap-managed group: the real directory of
/// Finder Alias files (not symlinks — confirmed via live-Dock verification that
/// raw symlinks aren't reliably rendered, while Finder Aliases are) a Dock folder
/// tile points at. Never moves or copies the member apps themselves.
public enum GroupStore {
    /// `~/.dockswap/groups/` — the root all group backing directories live under.
    public static func groupsRoot() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".dockswap/groups", isDirectory: true)
    }

    /// A fresh, unique backing-directory path for a new group under `presetName`.
    /// Doesn't create anything on disk — pass the result to `materialize(at:members:)`.
    /// The UUID never changes once assigned, even if the group is later renamed,
    /// so the preset's stored folder `path` stays stable across renames.
    public static func newGroupPath(presetName: String) -> URL {
        groupsRoot()
            .appendingPathComponent(presetName, isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    /// Ensures `path` exists as a directory containing exactly one Finder Alias
    /// per member. Idempotent and convergent: safe to call repeatedly as the
    /// member list changes — adds aliases for new members, removes aliases for
    /// members no longer present. A member that can't be resolved to a real app
    /// (moved/deleted since it was added) is skipped rather than failing the
    /// whole call.
    public static func materialize(at path: String, members: [AppIdentity]) throws {
        let dir = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var desired: [String: AppIdentity] = [:]
        for member in members { desired[aliasFileName(for: member)] = member }

        let existingFiles = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        )) ?? []
        for file in existingFiles where desired[file.lastPathComponent] == nil {
            try? FileManager.default.removeItem(at: file)
        }

        for (fileName, member) in desired {
            let aliasURL = dir.appendingPathComponent(fileName)
            guard !FileManager.default.fileExists(atPath: aliasURL.path) else { continue }
            guard let targetURL = resolveURL(for: member) else { continue }
            let bookmark = try targetURL.bookmarkData(
                options: .suitableForBookmarkFile, includingResourceValuesForKeys: nil, relativeTo: nil)
            try URL.writeBookmarkData(bookmark, to: aliasURL)
        }
    }

    /// Deletes a group's entire backing directory.
    public static func dissolve(path: String) {
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: path))
    }

    static func aliasFileName(for identity: AppIdentity) -> String {
        if let path = identity.path { return (path as NSString).lastPathComponent }
        return (identity.bundleId ?? "app") + ".app"
    }

    static func resolveURL(for identity: AppIdentity) -> URL? {
        if let path = identity.path { return URL(fileURLWithPath: path) }
        // ponytail: bundleId-only members skip here (no AppKit in Core).
        // Editor always stores a path; capture (#10) will too.
        return nil
    }
}

import Foundation

/// `~/.dockswap/presets/` — created lazily, idempotent (ticket 006).
public func ensureWorkspace() throws -> URL {
    let dir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".dockswap/presets", isDirectory: true)
    do {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    } catch {
        throw DockSwapError.io("cannot create \(dir.path): \(error.localizedDescription)")
    }
    return dir
}

extension DockPreset {
    /// Overwrite-or-create `~/.dockswap/presets/<name>.json`.
    /// Preserves `createdAt` on overwrite, bumps `updatedAt`.
    public func save(to name: String) throws {
        try validatePresetName(name)
        let dir = try ensureWorkspace()
        let url = dir.appendingPathComponent("\(name).json")
        var preset = self
        preset.name = name
        let now = iso8601Now()
        if FileManager.default.fileExists(atPath: url.path),
           let existing = try? DockPreset.load(from: url) {
            preset.createdAt = existing.createdAt
        } else if preset.createdAt.isEmpty {
            preset.createdAt = now
        }
        preset.updatedAt = now

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(preset)
            try data.write(to: url, options: .atomic)
        } catch let e as DockSwapError {
            throw e
        } catch {
            throw DockSwapError.io("cannot write \(url.path): \(error.localizedDescription)")
        }
    }

    public static func load(named name: String) throws -> DockPreset {
        try validatePresetName(name)
        let dir = try ensureWorkspace()
        let url = dir.appendingPathComponent("\(name).json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw DockSwapError.presetNotFound(name)
        }
        return try load(from: url)
    }

    public static func load(from url: URL) throws -> DockPreset {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw DockSwapError.io("cannot read \(url.path): \(error.localizedDescription)")
        }
        let preset: DockPreset
        do {
            preset = try JSONDecoder().decode(DockPreset.self, from: data)
        } catch {
            throw DockSwapError.invalidPreset(url.lastPathComponent)
        }
        guard preset.schemaVersion == currentSchemaVersion else {
            throw DockSwapError.invalidPreset(
                "schemaVersion \(preset.schemaVersion) (want \(currentSchemaVersion))")
        }
        return preset
    }

    public static func list() throws -> [DockPreset] {
        let dir = try ensureWorkspace()
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.contentModificationDateKey]
            )
        } catch {
            throw DockSwapError.io("cannot list \(dir.path): \(error.localizedDescription)")
        }
        return try files
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { try load(from: $0) }
    }

    public static func delete(named name: String) throws {
        try validatePresetName(name)
        let dir = try ensureWorkspace()
        let url = dir.appendingPathComponent("\(name).json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw DockSwapError.presetNotFound(name)
        }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw DockSwapError.io("cannot delete \(url.path): \(error.localizedDescription)")
        }
    }
}

func iso8601Now() -> String {
    ISO8601DateFormatter().string(from: Date())
}

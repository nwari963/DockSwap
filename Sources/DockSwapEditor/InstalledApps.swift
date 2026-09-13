import Foundation

struct InstalledApp: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleId: String?
    let path: String
}

enum InstalledApps {
    /// Scans the usual app locations for `.app` bundles. Doesn't descend
    /// into a bundle's own contents (`.skipsPackageDescendants`), but does
    /// walk plain subfolders like "Utilities".
    static func scan() -> [InstalledApp] {
        let roots = [
            "/Applications",
            "/System/Applications",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path,
        ]
        var seenPaths = Set<String>()
        var apps: [InstalledApp] = []
        for root in roots {
            guard let enumerator = FileManager.default.enumerator(
                at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: nil,
                options: [.skipsPackageDescendants, .skipsHiddenFiles]
            ) else { continue }
            for case let url as URL in enumerator {
                guard url.pathExtension == "app" else { continue }
                guard seenPaths.insert(url.path).inserted else { continue }
                let bundle = Bundle(url: url)
                let name = (bundle?.infoDictionary?["CFBundleName"] as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                apps.append(InstalledApp(
                    id: bundle?.bundleIdentifier ?? url.path,
                    name: name,
                    bundleId: bundle?.bundleIdentifier,
                    path: url.path
                ))
            }
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

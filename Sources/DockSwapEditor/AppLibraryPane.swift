import SwiftUI
import DockSwapCore

/// Left pane: all installed apps, searchable. Hover reveals an add-to-dock arrow.
/// Apps already on the dock (by path or bundleId) are dimmed.
struct AppLibraryPane: View {
    let apps: [InstalledApp]
    let onDockPaths: Set<String>
    let onDockBundleIds: Set<String>
    let onAdd: (InstalledApp) -> Void

    @State private var searchText = ""

    private var filtered: [InstalledApp] {
        searchText.isEmpty
            ? apps
            : apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func isOnDock(_ app: InstalledApp) -> Bool {
        onDockPaths.contains(app.path)
            || (app.bundleId.map(onDockBundleIds.contains) ?? false)
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search apps", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(8)
            List(filtered) { app in
                AppLibraryRow(app: app, onDock: isOnDock(app)) {
                    onAdd(app)
                }
            }
            .listStyle(.plain)
        }
        .frame(minWidth: 240)
    }
}

private struct AppLibraryRow: View {
    let app: InstalledApp
    let onDock: Bool
    let onAdd: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack {
            Image(systemName: "app.fill")
                .foregroundStyle(.secondary)
            Text(app.name)
                .foregroundStyle(onDock ? .secondary : .primary)
            if onDock {
                Text("on dock").font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer()
            if hovering {
                Button {
                    onAdd()
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Add to Dock")
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

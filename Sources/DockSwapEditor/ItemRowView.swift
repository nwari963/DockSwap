import SwiftUI
import DockSwapCore

struct ItemRowView: View {
    @Binding var item: DockItem

    var body: some View {
        switch item {
        case .app(let app):
            HStack {
                Image(systemName: "app.fill").foregroundStyle(.secondary)
                VStack(alignment: .leading) {
                    Text(displayName(for: app))
                    if let path = app.identity.path {
                        Text(path).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

        case .folder(let folder):
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "folder.fill").foregroundStyle(.secondary)
                    Text((folder.path as NSString).lastPathComponent)
                }
                HStack {
                    Picker("View", selection: viewBinding()) {
                        Text("Auto").tag("auto")
                        Text("Grid").tag("grid")
                        Text("Fan").tag("fan")
                        Text("List").tag("list")
                    }
                    Picker("Display", selection: displayBinding()) {
                        Text("Folder").tag("folder")
                        Text("Stack").tag("stack")
                    }
                    Picker("Sort", selection: sortBinding()) {
                        Text("Name").tag("name")
                        Text("Date Added").tag("dateadded")
                        Text("Date Modified").tag("datemodified")
                        Text("Date Created").tag("datecreated")
                        Text("Kind").tag("kind")
                    }
                }
                .pickerStyle(.menu)
                .font(.caption)
                .labelsHidden()
            }

        case .url:
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "link").foregroundStyle(.secondary)
                    TextField("Title", text: titleBinding())
                }
                TextField("URL", text: urlBinding())
                    .font(.caption)
            }

        case .spacer:
            HStack {
                Image(systemName: "square.dashed").foregroundStyle(.secondary)
                Text("Spacer").foregroundStyle(.secondary)
            }
        }
    }

    private func displayName(for app: AppItemPayload) -> String {
        if let path = app.identity.path {
            return (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        }
        return app.identity.bundleId ?? "App"
    }

    // Each binding reads/writes through the parent enum by pattern-matching
    // on the current value of `item` — DockItem's associated payloads are
    // value types, so a folder/url edit has to round-trip through the case.
    private func viewBinding() -> Binding<String> {
        Binding(
            get: { if case .folder(let f) = item { return f.view ?? "auto" }; return "auto" },
            set: { newValue in if case .folder(var f) = item { f.view = newValue; item = .folder(f) } }
        )
    }
    private func displayBinding() -> Binding<String> {
        Binding(
            get: { if case .folder(let f) = item { return f.display ?? "folder" }; return "folder" },
            set: { newValue in if case .folder(var f) = item { f.display = newValue; item = .folder(f) } }
        )
    }
    private func sortBinding() -> Binding<String> {
        Binding(
            get: { if case .folder(let f) = item { return f.sort ?? "name" }; return "name" },
            set: { newValue in if case .folder(var f) = item { f.sort = newValue; item = .folder(f) } }
        )
    }
    private func titleBinding() -> Binding<String> {
        Binding(
            get: { if case .url(let u) = item { return u.title }; return "" },
            set: { newValue in if case .url(var u) = item { u.title = newValue; item = .url(u) } }
        )
    }
    private func urlBinding() -> Binding<String> {
        Binding(
            get: { if case .url(let u) = item { return u.url }; return "" },
            set: { newValue in if case .url(var u) = item { u.url = newValue; item = .url(u) } }
        )
    }
}

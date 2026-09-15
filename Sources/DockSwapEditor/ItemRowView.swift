import SwiftUI
import DockSwapCore

struct ItemRowView: View {
    @Binding var item: DockItem
    var onRenameGroup: ((String) -> Void)? = nil
    var onUngroupGroup: (() -> Void)? = nil
    var expanded: Bool = false

    @State private var isEditingName = false
    @State private var draftName = ""

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
                Spacer()
            }

        case .folder(let folder):
            // A DockSwap-managed group (members present) vs. a plain folder.
            if let members = folder.members {
                groupRow(name: folder.name, memberCount: members.count)
            } else {
                plainFolderRow(path: folder.path)
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
                Spacer()
            }
        }
    }

    // MARK: - Group row

    @ViewBuilder
    private func groupRow(name: String?, memberCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.blue)
                    .font(.title3)
                if isEditingName {
                    TextField("Group name", text: $draftName, onCommit: commitNameRename)
                        .textFieldStyle(.roundedBorder)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name ?? "Group").font(.headline)
                        Text("\(memberCount) member\(memberCount == 1 ? "" : "s")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        draftName = name ?? ""
                        isEditingName = true
                    }
                }
                Spacer()
                if let onUngroupGroup {
                    Button {
                        onUngroupGroup()
                    } label: {
                        Image(systemName: "arrow.uturn.backward.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Dissolve group")
                }
            }
            if expanded {
                // Member rows are rendered inline by the parent.
            }
        }
    }

    @ViewBuilder
    private func plainFolderRow(path: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "folder.fill").foregroundStyle(.secondary)
                Text((path as NSString).lastPathComponent)
                Spacer()
            }
            HStack {
                Picker("View", selection: viewBinding()) {
                    Text("Auto").tag("auto"); Text("Grid").tag("grid")
                    Text("Fan").tag("fan"); Text("List").tag("list")
                }
                Picker("Display", selection: displayBinding()) {
                    Text("Folder").tag("folder"); Text("Stack").tag("stack")
                }
                Picker("Sort", selection: sortBinding()) {
                    Text("Name").tag("name"); Text("Date Added").tag("dateadded")
                    Text("Date Modified").tag("datemodified")
                    Text("Date Created").tag("datecreated"); Text("Kind").tag("kind")
                }
                .pickerStyle(.menu).font(.caption).labelsHidden()
            }
        }
    }

    // MARK: - Actions

    private func commitNameRename() {
        let trimmed = draftName.trimmingCharacters(in: .whitespaces)
        isEditingName = false
        if !trimmed.isEmpty {
            onRenameGroup?(trimmed)
        }
    }

    // MARK: - Display

    private func displayName(for app: AppItemPayload) -> String {
        if let path = app.identity.path {
            return (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        }
        return app.identity.bundleId ?? "App"
    }

    // MARK: - Bindings (folder pickers + URL fields)

    private func viewBinding() -> Binding<String> {
        Binding(
            get: { if case .folder(let f) = item { return f.view ?? "auto" }; return "auto" },
            set: { if case .folder(var f) = item { f.view = $0; item = .folder(f) } })
    }
    private func displayBinding() -> Binding<String> {
        Binding(
            get: { if case .folder(let f) = item { return f.display ?? "folder" }; return "folder" },
            set: { if case .folder(var f) = item { f.display = $0; item = .folder(f) } })
    }
    private func sortBinding() -> Binding<String> {
        Binding(
            get: { if case .folder(let f) = item { return f.sort ?? "name" }; return "name" },
            set: { if case .folder(var f) = item { f.sort = $0; item = .folder(f) } })
    }
    private func titleBinding() -> Binding<String> {
        Binding(
            get: { if case .url(let u) = item { return u.title }; return "" },
            set: { if case .url(var u) = item { u.title = $0; item = .url(u) } })
    }
    private func urlBinding() -> Binding<String> {
        Binding(
            get: { if case .url(let u) = item { return u.url }; return "" },
            set: { if case .url(var u) = item { u.url = $0; item = .url(u) } })
    }
}

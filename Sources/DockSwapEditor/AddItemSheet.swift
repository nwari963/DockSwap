import SwiftUI
import AppKit
import UniformTypeIdentifiers
import DockSwapCore

struct AddItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (DockItem) -> Void

    @State private var kind: Kind = .app
    @State private var installedApps: [InstalledApp] = []
    @State private var searchText = ""
    @State private var urlTitle = ""
    @State private var urlString = ""

    enum Kind: String, CaseIterable, Identifiable {
        case app = "App", folder = "Folder", url = "URL", spacer = "Spacer"
        var id: String { rawValue }
    }

    private var filteredApps: [InstalledApp] {
        searchText.isEmpty
            ? installedApps
            : installedApps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 12) {
            Picker("Type", selection: $kind) {
                ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding([.horizontal, .top])

            switch kind {
            case .app:
                VStack {
                    TextField("Search", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                    List(filteredApps) { app in
                        Button {
                            add(.app(AppItemPayload(identity: AppIdentity(bundleId: app.bundleId, path: app.path))))
                        } label: {
                            HStack {
                                Text(app.name)
                                Spacer()
                                Text(app.path).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Button("Browse for App…") { browseForApp() }
                }

            case .folder:
                Spacer()
                Button("Choose Folder…") { browseForFolder() }
                Spacer()

            case .url:
                VStack(spacing: 8) {
                    TextField("Title", text: $urlTitle).textFieldStyle(.roundedBorder)
                    TextField("URL", text: $urlString).textFieldStyle(.roundedBorder)
                    Button("Add") {
                        add(.url(URLItemPayload(title: urlTitle, url: urlString)))
                    }
                    .disabled(urlTitle.isEmpty || urlString.isEmpty)
                }
                .padding()
                Spacer()

            case .spacer:
                Spacer()
                Button("Add Spacer") { add(.spacer) }
                Spacer()
            }

            Button("Cancel") { dismiss() }
                .padding(.bottom)
        }
        .frame(width: 420, height: 480)
        .onAppear {
            installedApps = InstalledApps.scan()
        }
    }

    private func add(_ item: DockItem) {
        onAdd(item)
        dismiss()
    }

    private func browseForApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let bundle = Bundle(url: url)
        add(.app(AppItemPayload(identity: AppIdentity(bundleId: bundle?.bundleIdentifier, path: url.path))))
    }

    private func browseForFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        add(.folder(FolderItemPayload(path: url.path)))
    }
}

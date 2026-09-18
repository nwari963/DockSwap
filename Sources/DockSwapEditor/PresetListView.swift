import SwiftUI
import DockSwapCore
import UniformTypeIdentifiers

struct PresetListView: View {
    @State private var presets: [DockPreset] = []
    @State private var errorMessage: String?
    @State private var showingNewPresetSheet = false
    @State private var editingPresetName: String?
    @State private var selectedPresets: Set<String> = []
    @State private var showingExporter = false
    @State private var exportData: Data?

    var body: some View {
        NavigationSplitView {
            List(presets, id: \.name, selection: $editingPresetName) { preset in
                VStack(alignment: .leading) {
                    Text(preset.name).font(.headline)
                    Text("\(preset.apps.count + preset.others.count) items · \(preset.updatedAt)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(preset.name)
                .swipeActions {
                    Button("Delete", role: .destructive) {
                        delete(preset)
                    }
                }
                .contextMenu {
                    Button(selectedPresets.contains(preset.name) ? "Deselect" : "Select") {
                        toggleSelection(preset.name)
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        delete(preset)
                    }
                }
                .background(
                    selectedPresets.contains(preset.name)
                    ? Color.accentColor.opacity(0.15)
                    : Color.clear
                )
            }
            .navigationTitle("DockSwap Presets")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewPresetSheet = true
                    } label: {
                        Label("New Preset", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if !selectedPresets.isEmpty {
                        Button("Export Selected (\(selectedPresets.count))") {
                            exportSelected()
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if !selectedPresets.isEmpty {
                        Button("Clear Selection") {
                            selectedPresets.removeAll()
                        }
                    }
                }
            }
        } detail: {
            if let editingPresetName, let preset = presets.first(where: { $0.name == editingPresetName }) {
                PresetEditorView(preset: preset, onSave: reload)
                    .id(preset.name)
            } else {
                Text("Select a preset to edit, or create a new one.")
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showingNewPresetSheet) {
            NewPresetSheet { name in
                createPreset(named: name)
            }
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportData.map { JSONFile(data: $0) },
            contentType: .json,
            defaultFilename: "dockswap-presets-\(ISO8601DateFormatter().string(from: Date())).json"
        ) { result in
            if case .failure(let error) = result {
                errorMessage = "\(error)"
            } else {
                errorMessage = "Exported \(selectedPresets.count) preset(s)"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if errorMessage?.hasPrefix("Exported") == true {
                        errorMessage = nil
                    }
                }
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
        .onAppear(perform: reload)
    }

    private func reload() {
        do {
            presets = try DockPreset.list()
        } catch {
            errorMessage = "\(error)"
        }
    }

    private func delete(_ preset: DockPreset) {
        do {
            try DockPreset.delete(named: preset.name)
            if editingPresetName == preset.name { editingPresetName = nil }
            selectedPresets.remove(preset.name)
            reload()
        } catch {
            errorMessage = "\(error)"
        }
    }

    private func createPreset(named name: String) {
        do {
            let now = ISO8601DateFormatter().string(from: Date())
            let preset = DockPreset(name: name, createdAt: now, updatedAt: now)
            try preset.save(to: name)
            reload()
            editingPresetName = name
        } catch {
            errorMessage = "\(error)"
        }
    }

    private func toggleSelection(_ name: String) {
        if selectedPresets.contains(name) {
            selectedPresets.remove(name)
        } else {
            selectedPresets.insert(name)
        }
    }

    private func exportSelected() {
        let selected = presets.filter { selectedPresets.contains($0.name) }
        guard !selected.isEmpty else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            exportData = try encoder.encode(selected)
            showingExporter = true
        } catch {
            errorMessage = "\(error)"
        }
    }
}

struct JSONFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct NewPresetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    let onCreate: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("New Preset").font(.headline)
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
                .onSubmit { create() }
            HStack {
                Button("Cancel") { dismiss() }
                Button("Create") { create() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty)
            }
        }
        .padding(24)
    }

    private func create() {
        guard !name.isEmpty else { return }
        onCreate(name)
        dismiss()
    }
}
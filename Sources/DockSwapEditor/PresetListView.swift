import SwiftUI
import DockSwapCore

struct PresetListView: View {
    @State private var presets: [DockPreset] = []
    @State private var errorMessage: String?
    @State private var showingNewPresetSheet = false
    @State private var editingPresetName: String?

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
            }
            .navigationTitle("DockSwap Presets")
            .toolbar {
                ToolbarItem {
                    Button {
                        showingNewPresetSheet = true
                    } label: {
                        Label("New Preset", systemImage: "plus")
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

import SwiftUI
import DockSwapCore

private struct EditableItem: Identifiable {
    let id = UUID()
    var item: DockItem
}

struct PresetEditorView: View {
    let preset: DockPreset
    let onSave: () -> Void

    @State private var appsItems: [EditableItem]
    @State private var othersItems: [EditableItem]
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var showingAddSheet: AddTarget?
    @State private var isApplying = false

    private enum AddTarget: Identifiable { case apps, others; var id: Self { self } }

    init(preset: DockPreset, onSave: @escaping () -> Void) {
        self.preset = preset
        self.onSave = onSave
        _appsItems = State(initialValue: preset.apps.map(EditableItem.init))
        _othersItems = State(initialValue: preset.others.map(EditableItem.init))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(preset.name).font(.title2).bold()
                Spacer()
                if let statusMessage {
                    Text(statusMessage).foregroundStyle(.secondary)
                }
                Button("Apply") { apply() }
                    .disabled(isApplying)
                Button("Save") { save() }
                    .keyboardShortcut("s", modifiers: .command)
            }
            .padding()

            List {
                Section("Apps (left of divider)") {
                    ForEach($appsItems) { $editable in
                        ItemRowView(item: $editable.item)
                    }
                    .onMove { appsItems.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { appsItems.remove(atOffsets: $0) }

                    Button {
                        showingAddSheet = .apps
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }

                Section("Others (right of divider)") {
                    ForEach($othersItems) { $editable in
                        ItemRowView(item: $editable.item)
                    }
                    .onMove { othersItems.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { othersItems.remove(atOffsets: $0) }

                    Button {
                        showingAddSheet = .others
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        }
        .frame(minWidth: 460, minHeight: 520)
        .sheet(item: $showingAddSheet) { target in
            AddItemSheet { item in
                switch target {
                case .apps: appsItems.append(EditableItem(item: item))
                case .others: othersItems.append(EditableItem(item: item))
                }
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: { Text(errorMessage ?? "") })
    }

    private func currentPreset() -> DockPreset {
        var p = preset
        p.apps = appsItems.map(\.item)
        p.others = othersItems.map(\.item)
        return p
    }

    private func save() {
        do {
            try currentPreset().save(to: preset.name)
            statusMessage = "Saved"
            onSave()
        } catch {
            errorMessage = "\(error)"
        }
    }

    private func apply() {
        isApplying = true
        statusMessage = "Applying…"
        let target = currentPreset()
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try target.save(to: preset.name)
                let engine = DockDiffEngine(dockUtil: try DockUtil.resolved())
                let result = try engine.apply(target)
                DispatchQueue.main.async {
                    isApplying = false
                    if let result {
                        statusMessage = "Switched (\(result.removed) removed, \(result.added) added)"
                    } else {
                        statusMessage = "Already applied"
                    }
                    onSave()
                }
            } catch {
                DispatchQueue.main.async {
                    isApplying = false
                    errorMessage = "\(error)"
                }
            }
        }
    }
}

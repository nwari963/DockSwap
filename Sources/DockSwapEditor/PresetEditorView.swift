import SwiftUI
import DockSwapCore

private struct EditableItem: Identifiable {
    let id = UUID()
    var item: DockItem
}

private struct GroupDraft: Identifiable {
    let id = UUID()
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
    @State private var expandedGroups: Set<UUID> = []
    @State private var groupDraft: GroupDraft?
    @State private var pendingMergeTarget: UUID?

    @StateObject private var drag = RowDragState()

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
                        rowView(for: $editable)
                            .onDrag {
                                drag.begin(editable.id)
                                return NSItemProvider(object: editable.id.uuidString as NSString)
                            }
                            .onDrop(of: [.text], delegate: RowDropDelegate(
                                targetID: editable.id,
                                drag: drag,
                                onHoldComplete: { sourceID in
                                    startMerge(from: sourceID, onto: editable.id)
                                }
                            ))
                    }
                    .onMove { appsItems.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { appsItems.remove(atOffsets: $0) }

                    Button { showingAddSheet = .apps } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }

                Section("Others (right of divider)") {
                    ForEach($othersItems) { $editable in
                        rowView(for: $editable)
                            .onDrag {
                                drag.begin(editable.id)
                                return NSItemProvider(object: editable.id.uuidString as NSString)
                            }
                            .onDrop(of: [.text], delegate: RowDropDelegate(
                                targetID: editable.id,
                                drag: drag,
                                onHoldComplete: { sourceID in
                                    startMerge(from: sourceID, onto: editable.id)
                                }
                            ))
                    }
                    .onMove { othersItems.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { othersItems.remove(atOffsets: $0) }

                    Button { showingAddSheet = .others } label: {
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
        .sheet(item: $groupDraft) { _ in
            GroupNameSheet { name in
                commitMerge(named: name)
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: { Text(errorMessage ?? "") })
    }

    @ViewBuilder
    private func rowView(for binding: Binding<EditableItem>) -> some View {
        let id = binding.wrappedValue.id
        VStack(alignment: .leading, spacing: 0) {
            ItemRowView(
                item: binding.item,
                onRenameGroup: { newName in renameGroup(id, to: newName) },
                onUngroupGroup: { ungroupGroup(id) },
                expanded: expandedGroups.contains(id)
            )

            if case .folder(let folder) = binding.wrappedValue.item,
               let members = folder.members,
               expandedGroups.contains(id) {
                ForEach(members) { member in
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.caption2).foregroundStyle(.tertiary)
                        if let path = member.path {
                            Text((path as NSString).lastPathComponent).font(.caption)
                        } else {
                            Text(member.bundleId ?? "app").font(.caption)
                        }
                    }
                    .padding(.leading, 24)
                }
            }
        }
    }

    // MARK: - Group actions

    private func renameGroup(_ id: UUID, to name: String) {
        if let idx = appsItems.firstIndex(where: { $0.id == id }),
           case .folder(var f) = appsItems[idx].item {
            f.name = name
            appsItems[idx].item = .folder(f)
        } else if let idx = othersItems.firstIndex(where: { $0.id == id }),
                  case .folder(var f) = othersItems[idx].item {
            f.name = name
            othersItems[idx].item = .folder(f)
        }
    }

    private func ungroupGroup(_ id: UUID) {
        func expand(_ items: inout [EditableItem]) {
            guard let idx = items.firstIndex(where: { $0.id == id }),
                  case .folder(let f) = items[idx].item,
                  let members = f.members else { return }
            let newItems = members.map { EditableItem(item: .app(AppItemPayload(identity: $0))) }
            items.replaceSubrange(idx..<(idx + 1), with: newItems)
        }
        expand(&appsItems)
        expand(&othersItems)
    }

    private func startMerge(from source: UUID, onto target: UUID) {
        guard source != target else { return }
        pendingMergeTarget = target
        groupDraft = GroupDraft()
    }

    private func commitMerge(named name: String) {
        groupDraft = nil
        guard let target = pendingMergeTarget else { return }
        pendingMergeTarget = nil

        guard let source = drag.sourceID else { drag.cancel(); return }
        guard source != target else { drag.cancel(); return }

        var sourceItem: DockItem?
        if let idx = appsItems.firstIndex(where: { $0.id == source }) {
            sourceItem = appsItems[idx].item
        } else if let idx = othersItems.firstIndex(where: { $0.id == source }) {
            sourceItem = othersItems[idx].item
        }

        var targetItem: DockItem?
        var targetIsApps = false
        var targetIndex: Int?
        if let idx = appsItems.firstIndex(where: { $0.id == target }) {
            targetItem = appsItems[idx].item; targetIsApps = true; targetIndex = idx
        } else if let idx = othersItems.firstIndex(where: { $0.id == target }) {
            targetItem = othersItems[idx].item; targetIsApps = false; targetIndex = idx
        }

        guard let s = sourceItem, let t = targetItem, let tIdx = targetIndex else {
            drag.cancel(); return
        }

        let mergedMembers = combinedMembers(s) + combinedMembers(t)
        let path = GroupStore.newGroupPath(presetName: preset.name).path
        do {
            try GroupStore.materialize(at: path, members: mergedMembers)
            let group = FolderItemPayload(path: path, name: name, members: mergedMembers)
            let groupRow = EditableItem(item: .folder(group))
            remove(source)
            remove(target)
            if targetIsApps {
                appsItems.insert(groupRow, at: min(tIdx, appsItems.count))
            } else {
                othersItems.insert(groupRow, at: min(tIdx, othersItems.count))
            }
            expandedGroups.insert(groupRow.id)
            statusMessage = "Grouped \(mergedMembers.count) apps"
        } catch {
            errorMessage = "\(error)"
        }
        drag.cancel()
    }

    private func combinedMembers(_ item: DockItem) -> [AppIdentity] {
        switch item {
        case .app(let a): return [a.identity]
        case .folder(let f): return f.members ?? []
        default: return []
        }
    }

    private func remove(_ id: UUID) {
        appsItems.removeAll { $0.id == id }
        othersItems.removeAll { $0.id == id }
    }

    // MARK: - Preset lifecycle

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

// MARK: - Drop delegate

private struct RowDropDelegate: DropDelegate {
    let targetID: UUID
    @ObservedObject var drag: RowDragState
    let onHoldComplete: (UUID) -> Void

    func dropEntered(info: DropInfo) {
        drag.hover(targetID)
        Task { @MainActor in
            while !drag.holdCompleted {
                try? await Task.sleep(for: .milliseconds(16))
            }
            if drag.hoverID == targetID, let source = drag.sourceID {
                onHoldComplete(source)
            }
        }
    }

    func dropExited(info: DropInfo) {
        if drag.hoverID == targetID {
            drag.hover(nil)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        true
    }
}

// MARK: - Group name prompt

struct GroupNameSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    let onCommit: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("New Group").font(.headline)
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
                .onSubmit { commit() }
            HStack {
                Button("Cancel") { dismiss() }
                Button("Create") { commit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
    }

    private func commit() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onCommit(trimmed)
        dismiss()
    }
}

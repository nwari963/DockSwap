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
    @State private var installedApps: [InstalledApp] = []
    @State private var showingDryRun = false
    @State private var dryRunDiff: (removes: [DiffItem], adds: [DiffItem])?
    @State private var dryRunApplied = false

    /// Paths/bundleIds currently on the dock in this preset (incl. group members).
    private var dockPaths: Set<String> {
        Set(appsItems.compactMap { itemPath($0.item) } + othersItems.compactMap { itemPath($0.item) })
    }
    private var dockBundleIds: Set<String> {
        Set(appsItems.compactMap { itemBundleId($0.item) } + othersItems.compactMap { itemBundleId($0.item) })
    }

    private func itemPath(_ item: DockItem) -> String? {
        switch item {
        case .app(let a): return a.identity.path
        case .folder(let f): return f.members?.count == nil ? f.path : nil
        default: return nil
        }
    }
    private func itemBundleId(_ item: DockItem) -> String? {
        switch item {
        case .app(let a): return a.identity.bundleId
        case .folder(let f): return nil
        default: return nil
        }
    }

    @StateObject private var drag = RowDragState()

    private enum AddTarget: Identifiable { case apps, others; var id: Self { self } }

    init(preset: DockPreset, onSave: @escaping () -> Void) {
        self.preset = preset
        self.onSave = onSave
        _appsItems = State(initialValue: preset.apps.map(EditableItem.init))
        _othersItems = State(initialValue: preset.others.map(EditableItem.init))
    }

    var body: some View {
        HSplitView {
            AppLibraryPane(
                apps: installedApps,
                onDockPaths: dockPaths,
                onDockBundleIds: dockBundleIds,
                onAdd: { app in
                    appsItems.append(EditableItem(item: .app(AppItemPayload(
                        identity: AppIdentity(bundleId: app.bundleId, path: app.path)))))
                }
            )
            VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(preset.name).font(.title2).bold()
                Spacer()
                if let statusMessage {
                    Text(statusMessage).foregroundStyle(.secondary)
                }
                Button("Preview Changes") { computeDryRun() }
                    .disabled(isApplying)
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
                                drag.begin(editable.id, section: "apps")
                                return NSItemProvider(object: editable.id.uuidString as NSString)
                            }
                            .onDrop(of: [.text], delegate: RowDropDelegate(
                                targetID: editable.id,
                                targetSection: "apps",
                                drag: drag,
                                onHoldComplete: { sourceID in
                                    startMerge(from: sourceID, onto: editable.id)
                                },
                                onDropComplete: { sourceID, sourceSection in
                                    handleDrop(sourceID: sourceID, sourceSection: sourceSection, targetID: editable.id, targetSection: "apps")
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
                                drag.begin(editable.id, section: "others")
                                return NSItemProvider(object: editable.id.uuidString as NSString)
                            }
                            .onDrop(of: [.text], delegate: RowDropDelegate(
                                targetID: editable.id,
                                targetSection: "others",
                                drag: drag,
                                onHoldComplete: { sourceID in
                                    startMerge(from: sourceID, onto: editable.id)
                                },
                                onDropComplete: { sourceID, sourceSection in
                                    handleDrop(sourceID: sourceID, sourceSection: sourceSection, targetID: editable.id, targetSection: "others")
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
        }
        .frame(minWidth: 720, minHeight: 520)
        .onAppear { installedApps = InstalledApps.scan() }
        .onReceive(NotificationCenter.default.publisher(for: .applyFromDryRun)) { _ in apply() }
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
        .sheet(isPresented: $showingDryRun) {
            DryRunView(
                applied: dryRunApplied,
                removes: dryRunDiff?.removes ?? [],
                adds: dryRunDiff?.adds ?? []
            )
        }
        .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: { Text(errorMessage ?? "") })
    }

    @ViewBuilder
    private func rowView(for binding: Binding<EditableItem>) -> some View {
        let id = binding.wrappedValue.id
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ItemRowView(
                item: binding.item,
                onRenameGroup: { newName in renameGroup(id, to: newName) },
                onUngroupGroup: { ungroupGroup(id) },
                onRemoveMember: { member in removeMember(member, from: id) },
                expanded: expandedGroups.contains(id)
                )
                RemoveArrowRow { remove(id) }
            }

            if case .folder(let folder) = binding.wrappedValue.item,
               let members = folder.members,
               expandedGroups.contains(id) {
                ForEach(members) { member in
                    memberRow(member, groupID: id)
                }
            }
        }
    }

    /// #13: expanded member row with remove-from-group context menu.
    @ViewBuilder
    private func memberRow(_ member: AppIdentity, groupID: UUID) -> some View {
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
        .contextMenu {
            Button("Remove from Group", role: .destructive) {
                removeMember(member, from: groupID)
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

    /// #13: remove a single member from a group row — updates `members` in the
    /// preset state and deletes the alias from the backing directory.
    private func removeMember(_ member: AppIdentity, from groupID: UUID) {
        func strip(_ items: inout [EditableItem]) -> Bool {
            guard let idx = items.firstIndex(where: { $0.id == groupID }),
                  case .folder(var f) = items[idx].item,
                  let members = f.members else { return false }
            f.members = members.filter { $0 != member }
            if f.members?.isEmpty == true {
                // Last member gone: dissolve the backing dir and drop the row.
                GroupStore.dissolve(path: f.path)
                items.remove(at: idx)
            } else {
                GroupStore.removeMember(at: f.path, member: member)
                items[idx].item = .folder(f)
            }
            return true
        }
        _ = strip(&appsItems) || strip(&othersItems)
    }

    // MARK: - Cross-section drag-drop

    private func handleDrop(sourceID: UUID, sourceSection: String, targetID: UUID, targetSection: String) {
        // Find source item and remove from its section
        var sourceItem: DockItem?
        if sourceSection == "apps" {
            if let idx = appsItems.firstIndex(where: { $0.id == sourceID }) {
                sourceItem = appsItems[idx].item
                appsItems.remove(at: idx)
            }
        } else {
            if let idx = othersItems.firstIndex(where: { $0.id == sourceID }) {
                sourceItem = othersItems[idx].item
                othersItems.remove(at: idx)
            }
        }

        guard let item = sourceItem else { return }

        // Check if target is a group (folder with members) — drop-inside-group
        func addToGroup(_ items: inout [EditableItem]) -> Bool {
            guard let idx = items.firstIndex(where: { $0.id == targetID }),
                  case .folder(var f) = items[idx].item,
                  f.members != nil else { return false }
            // Add app to group members
            if case .app(let app) = item {
                f.members?.append(app.identity)
            } else if case .folder(let folder) = item {
                // If dropping a group onto a group, merge members
                f.members?.append(contentsOf: folder.members ?? [])
            }
            items[idx].item = .folder(f)
            return true
        }

        // Try adding to group in target section first
        if targetSection == "apps" {
            if addToGroup(&appsItems) { return }
        } else {
            if addToGroup(&othersItems) { return }
        }

        // Otherwise insert at section level (existing cross-section behavior)
        if targetSection == "apps" {
            if let idx = appsItems.firstIndex(where: { $0.id == targetID }) {
                appsItems.insert(EditableItem(item: item), at: idx)
            } else {
                appsItems.append(EditableItem(item: item))
            }
        } else {
            if let idx = othersItems.firstIndex(where: { $0.id == targetID }) {
                othersItems.insert(EditableItem(item: item), at: idx)
            } else {
                othersItems.append(EditableItem(item: item))
            }
        }
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

    private func computeDryRun() {
        let target = currentPreset()
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let engine = DockDiffEngine(dockUtil: try DockUtil.resolved())
                let current = try engine.captureCurrentPreset()
                let (removes, adds) = diff(target, from: current)
                let applied = isApplied(target, to: current)
                DispatchQueue.main.async {
                    dryRunDiff = (removes, adds)
                    dryRunApplied = applied
                    showingDryRun = true
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = "\(error)"
                }
            }
        }
    }
}

// MARK: - Hover remove arrow (right pane rows)

struct RemoveArrowRow: View {
    let onRemove: () -> Void
    @State private var hovering = false

    var body: some View {
        Group {
            if hovering {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Remove from Dock")
            } else {
                Color.clear.frame(width: 0, height: 0)
            }
        }
        .onHover { hovering = $0 }
    }
}

// MARK: - Drop delegate

private struct RowDropDelegate: DropDelegate {
    let targetID: UUID
    let targetSection: String
    @ObservedObject var drag: RowDragState
    let onHoldComplete: (UUID) -> Void
    let onDropComplete: (UUID, String) -> Void

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
        if let source = drag.sourceID, let sourceSection = drag.sourceSection {
            onDropComplete(source, sourceSection)
        }
        return true
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

// MARK: - Dry-run preview

struct DryRunView: View {
    @Environment(\.dismiss) private var dismiss
    let applied: Bool
    let removes: [DiffItem]
    let adds: [DiffItem]

    var body: some View {
        VStack(spacing: 16) {
            Text("Preview Changes").font(.title2).bold()

            if applied {
                Text("This preset is already applied to the Dock.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            } else if removes.isEmpty && adds.isEmpty {
                Text("No changes detected.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if !removes.isEmpty {
                            Text("Will remove (\(removes.count))").font(.headline).foregroundStyle(.red)
                            ForEach(removes, id: \.item.description) { item in
                                HStack {
                                    Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                                    icon(for: item.item)
                                    Text(item.item.description)
                                    Spacer()
                                    Text(item.section.rawValue.capitalized).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }

                        if !adds.isEmpty {
                            Text("Will add (\(adds.count))").font(.headline).foregroundStyle(.green)
                            ForEach(adds, id: \.item.description) { item in
                                HStack {
                                    Image(systemName: "plus.circle.fill").foregroundStyle(.green)
                                    icon(for: item.item)
                                    Text(item.item.description)
                                    Spacer()
                                    Text(item.section.rawValue.capitalized).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 300)
            }

            HStack {
                Button("Cancel") { dismiss() }
                if !applied && (!removes.isEmpty || !adds.isEmpty) {
                    Button("Apply Changes") {
                        dismiss()
                        NotificationCenter.default.post(name: .applyFromDryRun, object: nil)
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(minWidth: 480)
    }

    @ViewBuilder
    private func icon(for item: DockItem) -> some View {
        switch item {
        case .app(let app):
            Image(systemName: "app.fill").foregroundStyle(.secondary)
        case .folder(let folder):
            Image(systemName: folder.members != nil ? "folder.fill" : "folder")
                .foregroundStyle(folder.members != nil ? .blue : .secondary)
        case .url:
            Image(systemName: "link").foregroundStyle(.secondary)
        case .spacer:
            Image(systemName: "square.dashed").foregroundStyle(.secondary)
        }
    }
}

extension Notification.Name {
    static let applyFromDryRun = Notification.Name("applyFromDryRun")
}
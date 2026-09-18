# Ticket 014: UI - Drag-and-Drop Editor Enhancement

## Goal
Add drag-and-drop reordering capability to the `DockSwapEditor` window for intuitive preset editing.

## Scope
- Enable intra-section reordering (within "Apps" or "Others")
- Enable inter-section movement (Apps ↔ Others)
- Treat Groups as atomic rows (no drop-inside-group)
- Add sidebar listing all available presets for quick navigation

## Technical Approach
- Leverage existing `RowDragState` and split-pane layout from #12/#13
- Use native SwiftUI `onDrop` and `onMove` handlers
- No new dependencies; pure AppKit/SwiftUI integration
- Update preview data model to reflect drag state

## Acceptance Criteria
- [ ] Items can be dragged within their section and reordered visually
- [ ] Items can be dropped into the opposite section (logical move only)
- [ ] Groups render as single row items; cannot receive drops
- [ ] Sidebar shows all presets in ~/.dockswap/presets/
- [ ] Build passes; 26+ tests continue to pass

## Skipped
- Physical folder creation on section move (logical JSON update only)
- Drop-inside-group functionality (deferred to future iteration)

## Files to Touch
- `Sources/DockSwapEditor/PresetListView.swift` (sidebar addition)
- `Sources/DockSwapEditor/ItemRowView.swift` (drag/drop handlers)
- `Sources/DockSwapEditor/PresetEditorView.swift` (integration)

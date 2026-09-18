# Ticket 017: UI - Preset Sidebar Navigation

## Goal
Integrate a navigable sidebar into the `DockSwapEditor` window allowing users to quickly load and switch between saved presets without leaving the main editing pane.

## Scope
- Build a persistent sidebar panel next to the primary split-pane editor.
- Populate the sidebar by scanning `~/.dockswap/presets/` for valid JSON files (reusing the existing `Store` and `FileManager` logic).
- Enable single-click loading of a preset to replace the current active editing context.
- Display the "Last Applied" preset as the default initial selection if history tracking is implemented.

## Technical Approach
- Leverage SwiftUI's `NavigationSplitView` or a basic `HStack` with a scrollable list (`List`) to house the sidebar.
- Inject existing `Store` logic to read/write metadata without modifying core model definitions.
- Maintain compact, text-based presentation for preset names to minimize screen real estate usage.

## Acceptance Criteria
- [ ] Sidebar populates dynamically with available presets.
- [ ] Clicking a sidebar item loads its JSON structure into the main editor pane.
- [ ] Sidebar persists its state across window resizes within the session.

## Skipped
- Full drag-and-drop reordering of sidebar elements itself (focused here on loading/navigation).

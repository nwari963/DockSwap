# Ticket 016: UI - Batch Export Functionality

## Goal
Enable users to select multiple presets from the editor and export them into a consolidated JSON archive file.

## Scope
- Implement multi-select logic within the sidebar/preset list.
- Create an "Export Selected" action/button.
- Generate a single `.json` archive containing the selected presets (bundling their contents).
- Ensure proper file save dialog (`FileImporter` / `NSOpenPanel` equivalent) integration.

## Technical Approach
- Extend the `PresetsListView` with a selection state array (binding to `SelectionManager`).
- Use `JSONEncoder` from Swift's Standard Library to serialize the `Preset` models.
- Keep the archive format strictly human-readable to maintain transparency.

## Acceptance Criteria
- [ ] Users can toggle selection states for individual presets.
- [ ] An exported archive contains all selected presets accurately.
- [ ] The system provides immediate success/error feedback upon file generation.

## Skipped
- Merge logic (combining presets into one active state). Merging is deferred to post-core implementation.

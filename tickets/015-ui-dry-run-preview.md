# Ticket 015: UI - Dry-Run Preview Integration

## Goal
Implement a visual confirmation step (modal or inline preview) that shows exactly what changes will occur when a preset is applied, providing parity with the CLI's `--dry-run` functionality.

## Scope
- Add a "Preview Changes" button/state within the `PresetEditorView`.
- Display a text-based or structured summary of planned mutations (e.g., "Removing X apps from Others", "Adding Y folder to Persistent Apps").
- Require explicit user confirmation before executing the actual `switch` logic via `DockUtil`/`DiffEngine`.
- If no changes are detected, prompt the user immediately that the preset is already applied or unmodified.

## Technical Approach
- Reuse the existing `DiffEngine` logic from `DockSwapCore` to calculate differences between the current preset state and the live dock (or between two states).
- Render the output into a simple `Alert` or custom `VStack` modal using native SwiftUI views.
- No external charting or graphing libraries required; a simple text summary aligns with Ponytail constraints.

## Acceptance Criteria
- [ ] User can view the diff of a pending switch without committing it.
- [ ] Visual cues indicate added vs removed items (e.g., standard green/red indicators or icons).
- [ ] Switching proceeds only after explicit user confirmation.

## Skipped
- Complex graphical diffs or animations. Text is sufficient for the MVP scope.

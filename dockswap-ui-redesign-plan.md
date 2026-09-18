# DockSwap UI Redesign Plan

## Summary

Scope locked for functionality-focused UI expansion addressing workflow gaps while maintaining simplicity and avoiding over-engineering.

## Core Features

1. **Enhanced Editor (Split-Pane + Drag-Drop)**
   - Intra-section reordering within "Persistent Apps" and "Others"
   - Inter-section drag-and-drop between sections
   - Sidebar showing available presets for quick switching

2. **Dry-Run Preview**
   - Modal or inline text diff showing planned mutations
   - User confirms before applying changes

3. **Batch Operations**
   - Multi-select presets for batch export (JSON archive)
   - Serial application/merging deferred to post-core phase

4. **User Experience**
   - Default to load last-applied preset on startup
   - Minimal visual feedback (no dedicated undo - rely on preset re-loading)

---

## Technical Constraints
- Native SwiftUI only (no external UI frameworks)
- Reuse existing `DockSwapCore` models and logic
- Maintain single-monitor scope boundary
- Keep menu-bar app for post-MVP

---

## Out of Scope (Post-MVP)
- Dedicated Undo functionality
- Group nesting via drag/drop
- Multi-monitor awareness
- Menu-bar status app
- Batch serial application/merging

## Implementation Tickets
1. [014] UI - Drag-and-Drop Editor Enhancement
2. [015] UI - Dry-Run Preview Integration
3. [016] UI - Batch Export Functionality
4. [017] UI - Preset Sidebar Navigation

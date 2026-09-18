# CONTEXT.md

## Updated Domain Model for DockSwap UI Redesign

### Key Decisions:

1. **Drag-and-Drop Scope**:
   - Drag operations apply to sections ("Persistent Apps" ↔ "Others").
   - Group nesting via drag/drop deferred (groups treated as atomic rows).

2. **Batch Operations**:
   - Multi-select for batch-export (archived JSON).
   - Serial application merging deferred to avoid complexity.

3. **Dry-Run Preview**:
   - Editor integrates inline or modal text diffs.
   - Avoid deep parceling of JSON mutations, mirror CLI simplicity.

4. **Undo Strategy**:
   - Skip dedicated Undo UI (re-loadable preset compensates).

5. **Preset Display in Editor**:
   - Sidebar added containing navigable presets.
   - Inline preset row display maintained compact for focus ease.

---
### Why These Constraints?
DockSwap explicitly assumes:
1. General users over niche advanced workflows.
2. Minimum-mutation-safe UX verified mirrors `dockutil`'s fork.
3. "Choose Always Simpler Until Complexity-Noitional" aligns derailment minimality flows.
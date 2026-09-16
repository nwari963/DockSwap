# HANDOFF

> Shared baton for any coding agent. Read this first. Update it before you stop.

## Now
- **Goal:** Visual app grouping in DockSwapEditor — spec nwari963/DockSwap#8.
- **Current task:** none in flight. #9–#12 landed. **#13 is OPEN and unimplemented** (manage existing group: member-remove, context menus).
- **Status:** ready for next step.

## Next step
#13 (manage existing group) — extend `ItemRowView`/`PresetEditorView` with member-remove + context menus. #12 already added group-row rename + dissolve, so #13 is mostly member removal + context-menu actions.

## State
- **Done:** #9 (commit 3f28014) — schema `name`/`members`, `GroupStore.materialize`/`dissolve`, apply wiring, live-verified. #11 (commit 376c88d) — delete cascade + test, live-verified. #10 (commit 768cf93) — `GroupStore.recognizeGroup` seam, capture round-trip, bare-path folder rows, live-verified switch→save. #12 (commit 214194a) — hover-to-combine drag gesture, group-row render/rename/dissolve, `RowDragState`, `AppIdentity: Identifiable`; build clean, 26/26 tests, app launches.
- **In progress:** —
- **Blocked / needs decision:** concurrent Claude Code sessions race on `~/.dockswap` and this worktree — they stage files (one commit had to be amended to drop a swept-in 84KB transcript) and overwrite fixtures mid-verify. Check `git status` and fixture JSON before every commit/switch.

## Key facts
- **Build / verify:** `swift build && swift test --filter DockSwapCoreTests` (26 tests).
- **Watch out:** `dockutil --label` survives Dock restarts (verified). `.localized` display-name folders do NOT work on macOS 26 — don't pursue. dockutil restarts the Dock on every add/remove.
- **Decisions:** groups at `~/.dockswap/groups/<preset>/<uuid>/` (Finder Alias dirs); schemaVersion stays 1; `--view grid --display folder --label <name>` on apply; delete cascades via `try?` no-op; capture recognizes via `GroupStore.recognizeGroup` (nil = plain folder); `--list` folder rows come in two formats — `file://` URLs (native tiles) and bare POSIX paths (dockutil-added dirs).

## Log
- 2026-09-15 09:40 · ori-ai · #12 implemented (hover-to-combine gesture, RowDragState, group rows), build clean 26/26, launched, committed 214194a, closed. #13 remains.


# Switch Semantics — RESOLVED

## Question

What exactly happens on `dockswap switch <name>`?

- Diff-based apply (remove only what's not in target, add missing) vs. teardown-and-rebuild
- Should switching close running apps not in the target preset? (DockFlow does)
- Should it launch apps in the target preset? (DockFlow does)
- Missing apps on disk: skip with warning, or fail?
- Preserve: recent apps section, trash, minimized windows?
- Order: remove → add → single dock restart

## Resolution (2026-09-06)

**Model: a preset is exhaustive replacement of the pinned Dock.** `switch` makes the two persistent sections (`persistent-apps` + `persistent-others`) exactly match the preset, and touches nothing else. (`save` captures both sections wholesale, so Trash/stacks/spacers are part of the preset if the user had them pinned at capture time — no special-casing needed.)

**Apply = diff, not teardown.**
- Parse `dockutil --list`; ignore `recent-apps` rows.
- Removals: each currently-pinned item not in the target preset is removed **by explicit identity** (label/URL from `--list`). Never `--remove all` — that would nuke recent-apps and any Dock-managed tiles whose `dock-extra` flag `--list` doesn't expose.
- Additions: preset items missing from the current dock are added in **preset order**, each anchored `--position after <the preceding preset item already in place>` (first item falls back to `--position beginning` if the section head is empty). Anchoring in preset order is what preserves the preset's exact layout.
- **Short-circuit:** if current pinned set equals the preset, print `already applied`, exit 0, mutate nothing, no Dock restart.
- All removals+adds go in **one dockutil invocation**, no `--no-restart` → dockutil does exactly **one** Dock restart at the end.
- Final state is idempotent: switching twice is a no-op the second time.

**Never closes apps, never launches apps.** Closing/launching is app lifecycle, not Dock state — destructive (unsaved work) and surprising. Out of MVP; revisit post-MVP as explicit opt-in flags only.

**Missing-on-disk items: skip with a stderr warning, continue, exit 0.** Resolve each preset item by its schema-defined identity (bundle-id preferred, path fallback — see ticket 001); unresolved items are warned and skipped, the rest of the diff still applies. Fail-fast would brick the whole switch over one moved or volume-unmounted app.

**Preserve:**
- `recent-apps` — outside the diff scope, never touched.
- Minimized windows — not plist items, nothing to do.
- Dock-managed extras (e.g. `dock-extra` tiles) — preserved implicitly: we only remove identities `--list` shows and the preset doesn't pin; we never issue blanket deletes.

**Safety:**
- `switch` is the only mutating Dock command. A dockutil nonzero exit → abort, leave the Dock as-is, return non-zero (no MVP rollback; dockutil's own restart already didn't happen on failure).
- `--dry-run` (from ticket 004) prints the planned removal/add lists without applying.
- Exit codes follow ticket 004: 2 = preset not found, 3 = dockutil missing; skipped-missing-apps stay exit 0 (Dock is in a coherent, best-effort state).

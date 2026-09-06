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
- **Identity matching (how a preset item equals a `--list` row)** — the diff's core rule:
  1. If both sides have a `bundleId`: match on bundleId only (paths may differ between `/Applications` and `/System/Applications`).
  2. Else canonicalize both paths and compare: expand `~`, strip `file://` scheme, strip trailing `/`, resolve symlinks, and try `/System/Applications` ↔ `/Applications` equivalents.
  3. URL items: exact string match on the url.
  4. `label` is **never** a match key — it is only used as the dockutil anchor (label/path/bundle-id accepted by `--remove`/`--position after`).
  5. `--list` rows with empty label AND empty url AND empty bundleId are **spacer rows**: never removal candidates, never match candidates.
- Removals: each currently-pinned item not in the target preset is removed **by explicit identity** (label/URL from `--list`), **only if** the row has a resolvable identity (non-empty label or url). Never `--remove all` — that would nuke recent-apps and any Dock-managed tiles whose `dock-extra` flag `--list` doesn't expose. Rows whose identity cannot be represented in the preset schema are left in place and reported.
- Additions: preset items missing from the current dock are added in **preset order**, each anchored `--position after <the preceding preset item, whether pre-existing or added earlier in the same batch>`; the first item in a section falls back to `--position beginning` if the section head is empty. dockutil processes `--add` args sequentially, so anchoring to a just-added item is safe. Each add carries `--section apps|others`.
- **Arg order in the batched invocation: all `--remove` args first, then all `--add` args**, each set in preset order.
- **Short-circuit:** if current pinned set equals the preset, print `already applied`, exit 0, mutate nothing, no Dock restart.
- All removals+adds go in **one dockutil invocation**, no `--no-restart` → dockutil does exactly **one** Dock restart at the end.
- Final state is idempotent: switching twice is a no-op the second time.

**Never closes apps, never launches apps.** Closing/launching is app lifecycle, not Dock state — destructive (unsaved work) and surprising. Out of MVP; revisit post-MVP as explicit opt-in flags only.

**Missing-on-disk items: skip with a stderr warning, continue, exit 0.** Resolve each preset item by its schema-defined identity (bundle-id preferred, path fallback — see ticket 001); unresolved items are warned and skipped, the rest of the diff still applies. Fail-fast would brick the whole switch over one moved or volume-unmounted app.

**Preserve:**
- `recent-apps` — outside the diff scope, never touched.
- Minimized windows — not plist items, nothing to do.
- Dock-managed extras (e.g. `dock-extra` tiles) — removal is restricted to rows with a resolvable identity that the preset doesn't pin (see matching rules above); we never issue blanket deletes, and unidentifiable rows are never removal candidates.
- Trash — *expected* to survive as a captured `others` item or a non-removable row; **verify on live dock during QA** before relying on it.

**Safety:**
- `switch` is the only mutating Dock command. A dockutil nonzero exit → abort, leave the Dock as-is, return non-zero (no MVP rollback; dockutil's own restart already didn't happen on failure).
- `--dry-run` (from ticket 004) prints the planned removal/add lists without applying.
- Exit codes follow ticket 004: 2 = preset not found, 3 = dockutil missing; skipped-missing-apps stay exit 0 (Dock is in a coherent, best-effort state).

# Ranked review — BUILD-PLAYBOOK.md vs research + ticket resolutions
Date: 2026-09-06 · Repo state: clean @ 9cb74c7 · No code yet (pre-build audit)

## P0

### 1. Diff-engine identity-matching rules are unspecified
- File: tickets/003-switch-semantics.md:20-22, BUILD-PLAYBOOK.md §3
- Evidence: diff/short-circuit depend on matching preset items to `--list` rows, but `--list` gives only label/url/section/bundle-id (research §1). bundle-id is empty for folders, URLs, spacers. Paths differ in form: preset `~/Projects` vs dock `file:///Users/x/Projects`; system apps resolve `/System/Applications` vs `/Applications` (dockutil itself falls back between them).
- Correction: add an equivalence spec to §3 before implementing: (a) match by bundleId when both sides have one; (b) else canonicalize paths (expand `~`, strip `file://`, trailing `/`, resolve symlinks, try `/System/Applications` ↔ `/Applications`) and compare; (c) label is never a match key, only a dockutil anchor. This is the core correctness decision the playbook currently leaves open.

## P1

### 2. Capture fidelity gap: stack options and spacers are not representable from `--list`
- File: tickets/001…:73-79 (`folder` requires view/display/sort), tickets/002…:27 (flags the limit), BUILD-PLAYBOOK.md §1
- Evidence: `--list` exposes no view/display/sort and no spacer subtype. Capture must fabricate required folder fields; any switch that reorders or re-adds a stack silently resets its options. Spacers surface as label-empty/url-empty rows — if dropped at capture, the next switch removes them.
- Correction: make view/display/sort optional (dockutil defaults on add); capture empty-identity rows as `spacer`; verify against a live `dockutil --list` on this host before freezing the parser (dockutil not installed here — install it as build step 0).

### 3. "Never removes Dock-managed tiles" is unenforceable as specced
- File: tickets/003-switch-semantics.md:33, BUILD-PLAYBOOK.md §3
- Evidence: protection is implicit-only ("preset captured them"), but the schema cannot represent every tile `--list` emits (dock-extra rows, possible Trash/stack specials). Any unrepresentable current row not in the preset gets removed.
- Correction: add an explicit rule: removal candidates are only rows whose identity resolves AND that are absent from the preset; rows with empty label+url+bundleId are never removal candidates (spacer handling is positional instead). Soften the Trash claim in 003 ("Trash… no special-casing needed") to "verify on live dock".

### 4. `DOCKSWAP_DOCKUTIL_PATH` doesn't override anything
- File: tickets/002…:18 (PATH first, then config'd path), tickets/006…:27,33 (calls it an override)
- Evidence: with any dockutil on PATH, the env var is dead — but the var exists precisely to point at a non-PATH binary (custom build, testing).
- Correction: resolution order = env var → PATH → fail. One-line change in §2/§6 of the playbook.

### 5. Add-anchoring wording can produce reversed docks
- File: tickets/003-switch-semantics.md:21
- Evidence: "anchored `--position after <the preceding preset item already in place>`" — a strict reader anchors only to pre-existing items, so consecutive new adds after the first fall back to `beginning` → reversed order. dockutil processes `--add` args sequentially, so anchoring to a just-added item works.
- Correction: reword: "anchor after the preceding preset item (pre-existing or added earlier in the same batch); emit all `--remove` args before `--add` args, in preset order, with `--section apps|others` per item."

## P2

### 6. WAYFINDER.md drift
- Evidence: "Not yet specified" still lists Preset schema / First-run / Testing / Distribution entries already resolved; Decisions so far lacks 001 and 006 entries (replacement workers updated only ticket files).
- Correction: sync the map; the playbook is the canonical handoff regardless.

### 7. `--version` parse tolerance unspecified
- Evidence: 002 assumes bare `3.1.3`; research never shows actual `--version` output. Correction: parse must accept both `3.1.3` and `dockutil 3.1.3` (take the first semver-ish token).

### 8. Overwrite semantics for createdAt/updatedAt unspecified
- File: tickets/004…:32 (silent overwrite), tickets/001:24. Correction: on re-save keep original createdAt, bump updatedAt.

### 9. Exit-code contract CI assertion vs "no integration on CI"
- File: tickets/004…:55 vs tickets/007…:30. Correction: spawn-based usage-error tests (bad name, unknown subcommand, missing preset) touch no dock and are CI-safe; state that explicitly.

### 10. TUI exit codes unspecified
- File: tickets/005. Correction: q/Esc cancel → 0; apply result mirrors switch's exit code.

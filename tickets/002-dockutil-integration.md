# dockutil Integration Strategy — RESOLVED

## Question

How does dockswap invoke dockutil?

- Shell out to `dockutil` binary (PATH or config'd path) vs. vendor/embed Swift source
- Version pinning: minimum dockutil version (3.x)
- Error handling: nonzero exit, stderr, missing binary → actionable message
- `--no-restart` semantics: batch multiple ops into one Dock restart
- Capturing current dock: `dockutil --list` output parsing vs. reading `com.apple.dock.plist` directly

## Resolution (2026-09-06)

**Shell out to the `dockutil` binary. Never embed or vendor. Never touch the plist directly.**

Research (research/dockutil-integration.md) + source verification (Dock.swift, DockUtil.swift):
- Resolving path: **`$DOCKSWAP_DOCKUTIL_PATH` first, then PATH**; run detection via `dockutil --version`. Version parse: take the first semver-ish token (`3.1.3`, `dockutil 3.1.3` both accepted).
- Embedding re-forks the entire Dock-write problem dockutil already solves (cfprefsd cache, opaque `book` bookmarks, one-restart semantics, sudo/asuser edge cases) and adds a vendored dependency to maintain. Ponytail: drive the tool, don't reimplement it. Defer embedding to post-MVP only if distribution demands it.

Decisions:
- **Shell out vs. embed**: Shell out via `Process`, always as the **invoking user** (never sudo/root — avoids the open defaults-hang family dockutil#126/#160/#153). Binary path resolved `$DOCKSWAP_DOCKUTIL_PATH` → PATH (env var wins; it exists to point at a non-PATH binary for testing/custom builds).
- **Version pinning**: Require dockutil **>= 3.0.0** (batching + Swift rewrite for macOS 12.3+); treat **3.1.3 as the practical minimum** (macOS 14.4 `launchctl kickstart` fix). Parse major from `dockutil --version`; if missing or < 3, fail with actionable message → first-run install path (006: `brew install dockutil`).
- **Error handling**: Capture stdout+stderr separately. Nonzero exit → print dockutil's stderr verbatim prefixed with the failing dockutil command. Exit 127 / exec failure → "dockutil not found — install with `brew install dockutil`". Never swallow warnings.
- **`--no-restart` semantics**: Normal switches **never pass `--no-restart`**. Batch every add/remove/move for a preset into a single dockutil invocation; dockutil's single restart bool does exactly one Dock terminate at the end of `save()` (confirmed in Dock.swift). `--no-restart` is reserved for a future explicit user flag / dry-run diff.
- **Capturing current dock**: Parse `dockutil --list` (tab-separated: `label<TAB>url<TAB>section<TAB>plist<TAB>bundle-id`). dockutil reads the cfprefsd cache the Dock itself uses; raw disk plist can be stale. **Never write the plist directly** — cfprefsd ignores disk writes.
  - Known `--list` fidelity limit, flagged as a 001 constraint: spacer tile *type* (spacer/small/flex) and folder/stack *view options* (grid/fan/list/auto, display-as, sort) are not exposed. Out of MVP capture scope; post-MVP fallback is `CFPreferencesCopyAppValue` (never raw disk) if fidelity is needed.

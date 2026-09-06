# DockSwap — BuildPlaybook

> Destination of the [Wayfinder map](WAYFINDER.md), assembled 2026-09-06. Every ticket (001–007) is resolved; this document is the decision-complete build spec. Hand to any build session as-is.
>
> **DockSwap**: a beautiful, lightweight, open-source macOS CLI that saves and switches Dock presets — an open DockFlow. Native Dock only, no permissions, no telemetry. Backend: `dockutil`. License: MIT.

## Product summary

| | |
|---|---|
| Binary | `dockswap` (Swift, SwiftPM; `DockSwapCore` lib + thin executable) |
| Only dependency | swift-argument-parser (Apache-2.0, Apple) |
| Backend | shells out to `dockutil` (>= 3.0, 3.1.3 practical min); never embeds, never touches the plist |
| Presets | JSON at `~/.dockswap/presets/<name>.json`, schemaVersion 1 |
| MVP verbs | `save`, `switch`, `list`, `delete`, bare-invocation TUI picker |
| Platform floor | macOS 13+ |

---

## 1. Preset schema (ticket 001)

`preset-v1`, JSON Schema draft-07. Top level: `name`, `schemaVersion: 1`, `createdAt`/`updatedAt` (ISO-8601), `dockutilVersion`, `macOSVersion`, and two ordered arrays: `apps` (left of divider) and `others` (right of divider). Identity: `bundleId` primary, `path` fallback (anyOf). Item types: `app`, `folder` (path+view+display+sort), `url` (title+url), `spacer`. Strict writer (`additionalProperties: false`), lenient reader (unknown fields preserved on rewrite). Full schema + example: [tickets/001-preset-schema-design.md](tickets/001-preset-schema-design.md).

Known capture limit (from 002): `dockutil --list` doesn't expose spacer sub-type or stack view options; post-MVP fallback is `CFPreferencesCopyAppValue`.

## 2. dockutil integration (ticket 002)

Shell out via `Process` as the invoking user (never sudo). Resolve binary: PATH → `$DOCKSWAP_DOCKUTIL_PATH` → fail with `brew install dockutil` hint (exit 3). Version gate on `--version`. One batched invocation per switch (adds+removes together) so dockutil restarts the Dock exactly once; never `--no-restart` in normal operation. Capture via `dockutil --list` (tab-separated: label, url, section, plist, bundle-id). Nonzero exit → echo stderr verbatim, abort, non-zero exit. Full detail: [tickets/002-dockutil-integration.md](tickets/002-dockutil-integration.md).

## 3. Switch semantics (ticket 003)

Preset = exhaustive replacement of the pinned Dock (`persistent-apps` + `persistent-others`), applied as a diff: explicit-identity removals + order-anchored additions (`--position after <preceding preset item>`, first falls back to `--position beginning`). Never `--remove all`. Short-circuit when already applied (exit 0, no restart). Never closes/launches apps (post-MVP opt-in flags only). Missing-on-disk items: skip + stderr warning, exit 0. Preserves recent-apps, minimized windows, dock-extras. Abort leaves Dock untouched. Idempotent. Full detail: [tickets/003-switch-semantics.md](tickets/003-switch-semantics.md).

## 4. CLI surface (ticket 004)

```
dockswap                        # TUI picker (005)
dockswap save <name>            # capture → preset (overwrites silently)
dockswap switch <name> [--dry-run] [--quiet]
dockswap list [--json] [--quiet]
dockswap delete <name> [--quiet]
dockswap --version / --help / --generate-completion-script <shell>
```

Preset names: `^[A-Za-z0-9][A-Za-z0-9._-]*$`. `--json` on `list` only (stable schema). Exit codes: 0 ok; 1 usage; 2 preset-not-found; 3 dockutil-missing; 4 invalid-preset-file; 5 dockutil-failed; 6 filesystem error. `main` uses `parseAsRoot` in do/catch to honor exit 1 (library default is 64) — asserted in CI. Full output shapes + example invocations: [tickets/004-cli-command-structure.md](tickets/004-cli-command-structure.md).

## 5. TUI picker (ticket 005)

Dependency-free ANSI raw-mode picker (~80–140 lines): termios raw mode, arrows+Enter, number shortcuts 1–9, q/Esc cancel, reverse-video highlight, cursor hide/show. Bare `dockswap` opens it; Enter applies (auto-apply); preview = second-Enter item list or `switch --dry-run`. Research verdict: no mature Swift TUI lib exists (TauTUI is young, Swift 6-only) — dependency-free is the right call. Full detail + NSStatusItem post-MVP sketch: [tickets/005-tui-design.md](tickets/005-tui-design.md), [research/swift-tui-options.md](research/swift-tui-options.md).

## 6. First-run & config (ticket 006)

Lazy idempotent `ensureWorkspace()` creates `~/.dockswap/presets/` (withIntermediateDirectories) at startup. No `init` command. dockutil resolved lazily only in `save`/`switch` (list/delete run dockutil-free), cached for process lifetime. No config file in MVP — every default is pinned by a decision; the single override is env var `DOCKSWAP_DOCKUTIL_PATH`. `save` captures the live dock; hand-edited JSON files are the manual path. Full detail: [tickets/006-first-run-config.md](tickets/006-first-run-config.md).

## 7. Build, test, distribution (ticket 007)

- **Layout**: SwiftPM, `.macOS(.v13)`, `DockSwapCore` library (model, dockutil wrapper, diff engine, picker) + `dockswap` executable (argument-parser surface only).
- **Tests**: `swift test` unit suite — Codable roundtrip w/ golden fixtures, diff engine edges, `--list` tab-parse fixtures, path resolution. Mock dockutil via injected `DockUtilExecuting` protocol. Opt-in integration tests (`DOCKSWAP_INTEGRATION=1`) never on CI (they mutate the live Dock).
- **CI**: GitHub Actions `ci.yml`, `macos-latest`, `swift build -c release` + `swift test`.
- **Distribution**: GitHub Releases (signed + notarized via `notarytool` when a Developer ID exists; unsigned with documented Gatekeeper workaround otherwise) + in-repo `Formula/dockswap.rb` tap; homebrew-core post-MVP.
- **Repo**: MIT LICENSE, README (install, quickstart, demo GIF via asciinema+agg), CONTRIBUTING.md with manual QA checklist. Full detail: [tickets/007-build-test-distribution.md](tickets/007-build-test-distribution.md).

---

## Build order (for the build session)

1. `swift package init` — Package.swift with both targets, pin swift-argument-parser `from: "1.3.0"`, `.macOS(.v13)`.
2. `DockSwapCore`: preset Codable model (001) + roundtrip tests w/ fixtures.
3. dockutil wrapper (002) with `DockUtilExecuting` protocol + fake; `--list` tab-parse tests.
4. Diff engine (003) + edge tests.
5. Executable: four verbs + bare-picker entry (004); exit-code contract incl. `parseAsRoot`/exit-1 behavior.
6. ANSI picker (005).
7. `ensureWorkspace()` + lazy dockutil resolution (006).
8. CI workflow, LICENSE, README, CONTRIBUTING (007).
9. Local manual QA pass (CONTRIBUTING checklist), then first GitHub Release.

## Post-MVP (deferred, not specced)

Global hotkeys, Focus-mode/Shortcuts integration, Lock Dock, preset import/export, menu-bar app (NSStatusItem), embedding dockutil, homebrew-core bottles, `--no-restart`/`--preview` flags, config file, close/launch app opt-ins, `CFPreferencesCopyAppValue` capture fidelity.

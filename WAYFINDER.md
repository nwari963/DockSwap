# Wayfinder Map: DockSwap

## Destination

A **BuildPlaybook** (`BUILD-PLAYBOOK.md`): the complete, decision-complete spec for building DockSwap — an open-source, lightweight `dockswap` CLI (Swift) that saves/switches macOS Dock presets via `dockutil`, JSON presets at `~/.dockswap/presets/`, TUI picker, optional menu-bar accessor. MVP: save, switch, list, delete. The map is done when every open decision ticket is resolved and the playbook can be handed to a build session with nothing left to decide.

## Notes

- **Domain**: macOS Dock management via `com.apple.dock.plist` manipulation
- **Backend**: `dockutil` (Swift CLI, 2K★, MIT) — shell out initially, consider embedding later
- **Language**: Swift (native, single binary, macOS ecosystem)
- **Storage**: JSON files at `~/.dockswap/presets/<name>.json`
- **CLI name**: `dockswap`
- **Skills to consult**: `prototype` for CLI design, `grilling` + `domain-modeling` for decisions
- **Principles**: Ponytail full — stdlib/native first, shortest diff, delete over add

## Decisions so far

- [Interface shape](tickets/005-tui-design.md): CLI/TUI + optional menu bar; Swift; JSON presets; MVP = save/switch/list/delete
- [Naming](tickets/005-tui-design.md): CLI `dockswap`, repo `dockswap`
- [TUI Design](tickets/005-tui-design.md): no TUI library; swift-argument-parser (only dep) + dependency-free ANSI raw-mode picker (~80-140 lines); bare `dockswap` opens picker; auto-apply on Enter
- [Switch Semantics](tickets/003-switch-semantics.md): preset = exhaustive replacement of pinned Dock; diff-based apply (explicit removes + order-anchored adds, one dockutil call = one restart); never closes/launches apps; missing apps skipped with warning; recent-apps/minimized-windows preserved
- [dockutil integration](tickets/002-dockutil-integration.md): shell out to dockutil binary (never embed, never write plist directly); require >= 3.0 (min 3.1.3); one batched invocation per switch, no `--no-restart`; run as invoking user; capture via `dockutil --list` tab-parse
- [CLI command structure](tickets/004-cli-command-structure.md): exactly four verbs — `save <name>`, `switch <name>` (`--dry-run`), `list` (`--json`, the only machine interface), `delete <name>` — plus bare `dockswap` picker entry; no `--no-restart`/`--preview` in MVP; exit codes 0–6 (1 usage, 2 preset-not-found, 3 dockutil-missing, 4 invalid-preset, 5 dockutil-failed, 6 io); shell completion via library `--generate-completion-script`
- [Build, test & distribution](tickets/007-build-test-distribution.md): SwiftPM package split into `DockSwapCore` library + `dockswap` executable; `.macOS(.v13)` min; swift-argument-parser only dep; unit tests on CI (macOS GitHub Actions runner), opt-in integration tests never on CI; MIT license; GitHub Releases (sign+notarize when cert available) + in-repo `Formula/dockswap.rb` tap, graduate to homebrew-core post-MVP

## Not yet specified

- **Preset schema design**: Exact JSON structure for a dock preset (app paths, bundle IDs, folder/stack/URL items, spacers, positions, sections)
- **Menu bar app**: Separate target or same binary with flag? Status item + popover; preset list with switch action
- **First-run experience**: Detect dockutil; guide install via Homebrew; create config dir; permissions (Accessibility for hotkeys later)
- **Config file**: `~/.dockswap/config.json` — dockutil path, preset dir, default behaviors
- **Post-MVP features**: Global hotkeys (Accessibility), Focus mode integration (Shortcuts), Lock Dock, preset import/export, multi-monitor awareness

## Out of scope

- GUI builder for presets (drag-and-drop) — MVP is capture current dock
- Cloud sync — local-first, JSON is portable
- Windows/Linux — macOS-only by design
- Dock replacement (like uBar) — we manage the native Dock only
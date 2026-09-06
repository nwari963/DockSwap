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

## Not yet specified

- **Preset schema design**: Exact JSON structure for a dock preset (app paths, bundle IDs, folder/stack/URL items, spacers, positions, sections)
- **dockutil integration strategy**: Shell out vs. embed Swift code; version pinning; error handling; --no-restart semantics
- **Switch operation semantics**: Close apps not in target preset? Launch missing apps? Handle missing apps gracefully? Order of operations (remove then add vs. diff)
- **CLI command structure**: Subcommands (`dockswap save <name>`, `dockswap switch <name>`, `dockswap list`, `dockswap delete <name>`), flags, output format
- **Menu bar app**: Separate target or same binary with flag? Status item + popover; preset list with switch action
- **First-run experience**: Detect dockutil; guide install via Homebrew; create config dir; permissions (Accessibility for hotkeys later)
- **Config file**: `~/.dockswap/config.json` — dockutil path, preset dir, default behaviors
- **Testing strategy**: Unit tests (preset parsing, diff logic); integration tests (real dock manipulation on CI?); manual QA checklist
- **Distribution**: Homebrew formula; GitHub Releases; notarization; code signing
- **Post-MVP features**: Global hotkeys (Accessibility), Focus mode integration (Shortcuts), Lock Dock, preset import/export, multi-monitor awareness

## Out of scope

- GUI builder for presets (drag-and-drop) — MVP is capture current dock
- Cloud sync — local-first, JSON is portable
- Windows/Linux — macOS-only by design
- Dock replacement (like uBar) — we manage the native Dock only
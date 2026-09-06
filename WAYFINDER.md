# Wayfinder Map: DockSwap

## Destination

A **BuildPlaybook** (`BUILD-PLAYBOOK.md`): the complete, decision-complete spec for building DockSwap — an open-source, lightweight `dockswap` CLI (Swift) that saves/switches macOS Dock presets via `dockutil`, JSON presets at `~/.dockswap/presets/`, TUI picker, optional menu-bar accessor. MVP: save, switch, list, delete. The map is done when every open decision ticket is resolved and the playbook can be handed to a build session with nothing left to decide.

## Notes

- **Domain**: macOS Dock management via `com.apple.dock.plist` manipulation
- **Backend**: `dockutil` (Swift CLI, 2K★, Apache-2.0) — shell out; never embed or link
- **Language**: Swift (native, single binary, macOS ecosystem)
- **Storage**: JSON files at `~/.dockswap/presets/<name>.json`
- **CLI name**: `dockswap`
- **Skills to consult**: `prototype` for CLI design, `grilling` + `domain-modeling` for decisions
- **Principles**: Ponytail full — stdlib/native first, shortest diff, delete over add

## Decisions so far

- [Preset schema design](tickets/001-preset-schema-design.md): `preset-v1`, bundleId-primary/path-fallback identity, apps/others arrays, optional folder options, spacer capture rule, timestamps, schemaVersion migration
- [CLI command structure](tickets/004-cli-command-structure.md): four verbs + bare picker, flags, exit codes 0-6, help/completion via library, save overwrite semantics
- [First-run experience & config](tickets/006-first-run-config.md): lazy init, no config file, dockutil detected lazily in save/switch only, env var `DOCKSWAP_DOCKUTIL_PATH` wins over PATH
- [Build, test & distribution](tickets/007-build-test-distribution.md): DockSwapCore lib + executable, swift-argument-parser only dep, macOS 13+, unit tests on CI, opt-in integration off CI, MIT, GH Releases + in-repo tap

## Not yet specified

- **Menu bar app**: NSStatusItem companion, post-MVP only — pure AppKit, no deps; not in MVP.
- **Post-MVP features**: Global hotkeys (Accessibility), Focus mode integration (Shortcuts), Lock Dock, preset import/export, multi-monitor awareness, embedding dockutil, homebrew-core bottles, `--no-restart`/`--preview` flags, config file, close/launch app opt-ins, `CFPreferencesCopyAppValue` capture fidelity.

## Out of scope

- GUI builder for presets (drag-and-drop) — MVP is capture current dock
- Cloud sync — local-first, JSON is portable
- Windows/Linux — macOS-only by design
- Dock replacement (like uBar) — we manage the native Dock only
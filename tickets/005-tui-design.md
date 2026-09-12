# TUI Design — RESOLVED

## Question

How should the interactive picker work?

## Resolution (2026-09-06)

**No TUI library. Dependency-free ANSI picker + swift-argument-parser.**

Research (research/swift-tui-options.md):
- No mature "BubbleTea for Swift" exists. Closest is TauTUI (MIT, Swift 6+, young).
- SwiftTerm is a terminal emulator, Splash is a syntax highlighter — not TUI libs.
- swift-argument-parser (Apple, Apache-2.0) is the CLI core — accepted despite Apache-2.0 (permissive).

Decisions:
- **CLI args**: swift-argument-parser (only dependency).
- **Picker**: raw-mode ANSI, ~80–140 lines, no dependency:
  - termios raw mode (tcgetattr/tcsetattr)
  - Arrow keys ESC[A/ESC[B, Enter \r
  - Reverse-video highlight, cursor hide/show
  - q/Esc to cancel
- **Navigation**: arrows + Enter; number keys as shortcut for first 9 presets.
- **Exit codes**: q/Esc cancel → 0 (no apply); Enter-apply → the chosen switch's exit code (success or failure propagates).
- **Preview**: list preset names with item counts; second Enter on preset shows item list before apply (or `--preview` flag). Default: single Enter applies, `--dry-run` prints diff.
- **Confirmation**: auto-apply on Enter. `dockswap switch` non-interactive path is the safe default; TUI is the power path.
- **Entry point**: bare `dockswap` (no args) opens the picker.

Post-MVP only: NSStatusItem menu-bar companion (pure AppKit, no deps) if wanted.

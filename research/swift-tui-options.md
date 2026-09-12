# Swift TUI Research for DockSwap

## 1. Does a mature "BubbleTea for Swift" exist?

**Short answer: no.**

- **Bubble Tea** itself is a Go library (`charmbracelet/bubbletea`, ~44k stars, Apache-2.0). It has no Swift port. The closest analogue is **TauTUI** (`steipete/TauTUI`, MIT, Swift 6+), a port of `pi-tui` with differential rendering, bracketed paste, autocomplete, and a component set. It has 4 releases after ~7 months of development. That is usable, but not mature in the way Bubble Tea is for Go. Source: [TauTUI README](https://github.com/steipete/TauTUI), [Swift Package Index](https://swiftpackageindex.com/steipete/TauTUI).
- Other candidates mentioned in search results, such as **ANSIKit** (`tornikegomareli/ANSIKit`, MIT) and **terminal-input** (`juri/terminal-input`, MIT), are tiny helper libraries for ANSI formatting or raw key reading; they are not full TUI frameworks. Source: [ANSIKit README](https://github.com/tornikegomareli/ANSIKit), [terminal-input README](https://github.com/juri/terminal-input).
- **SwiftTerm** (`migueldeicaza/SwiftTerm`, MIT) is a VT100/Xterm **terminal emulator** for embedding a terminal view in macOS/iOS apps. It is not a TUI framework for building interactive CLI pickers. Source: [SwiftTerm README](https://github.com/migueldeicaza/SwiftTerm), [Swift Package Index](https://swiftpackageindex.com/migueldeicaza/SwiftTerm).
- **Splash** (`JohnSundell/Splash`, MIT) is a **syntax highlighter** for generating HTML/attributed strings from source code. It is not a TUI library. Source: [Splash README](https://github.com/JohnSundell/Splash).

**Verdict:** there is no widely adopted, production-hardened "BubbleTea for Swift." TauTUI is the most complete native Swift TUI, but it is young and Swift 6–only.

---

## 2. CLI argument parsing

**swift-argument-parser** (`apple/swift-argument-parser`, Apache-2.0, Swift 5.8+) is the right core for DockSwap's CLI surface. It is Apple-maintained, source-stable, and used by Swift tooling itself. Source: [GitHub repo](https://github.com/apple/swift-argument-parser), [documentation](https://apple.github.io/swift-argument-parser/documentation/argumentparser/).

**Note on licensing:** Apache-2.0 is not MIT, but it is permissive. If the project's "MIT or similar" rule is strict, flag this. Otherwise it is fine.

---

## 3. Is a dependency-free ANSI picker viable, and how many lines?

**Yes, viable.** For a simple numbered-list picker with arrow keys + Enter on a single screen, raw terminal mode + ANSI escape codes is enough.

The basic moving parts in Swift on macOS:

1. Put stdin in raw/non-canonical mode with `termios` (`tcgetattr` / `tcsetattr`) so keys are delivered byte-by-byte without waiting for Return. Source: [Stack Overflow raw mode Swift example](https://stackoverflow.com/questions/53587666/how-to-read-ansi-escape-code-response-value-in-swift).
2. Read escape sequences for arrow keys (`\u{1b}[A`, `\u{1b}[B`, etc.) and Enter (`\u{0d}`).
3. Render with ANSI CSI sequences: cursor positioning (`\u{1b}[<row>;<col>H`), clearing (`\u{1b}[2J`), reverse video/highlight (`\u{1b}[7m`), reset (`\u{1b}[0m`).
4. Hide/show the cursor (`\u{1b}[?25l` / `\u{1b}[?25h`).

**Rough line count:** ~80–140 lines of Swift for a single-file implementation, including terminal setup/teardown, input loop, and renderer. The input handling and ANSI constants are the bulk; the list model itself is trivial.

**Caveat:** this is macOS-first. `termios` exists on Linux too, but DockSwap is macOS-only per the ticket context, so that is fine. Source: ticket `/Users/nwariri/OTH=RCOD=.DEV/EXPERIMENTS/DockSwap/tickets/005-tui-design.md`.

---

## 4. Menu-bar status item in pure Swift

For a DockSwap menu-bar companion, **NSStatusItem** is the native AppKit primitive and requires no third-party dependencies.

Minimal shape:

```swift
import AppKit

final class StatusController: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "dock.arrow.down", accessibilityDescription: "DockSwap")
        statusItem?.button?.action = #selector(togglePopover)

        let menu = NSMenu()
        presets.forEach { preset in
            menu.addItem(NSMenuItem(title: preset.name, action: #selector(selectPreset(_:)), keyEquivalent: ""))
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc private func togglePopover() { /* show/hide popover if richer UI is needed */ }
}
```

Key gotcha: keep a strong reference to `NSStatusItem`; otherwise ARC deallocates it immediately. Source: [Apple Developer docs](https://developer.apple.com/documentation/AppKit/NSStatusItem), [Swiftyn NSStatusBar guide](https://www.swiftyn.com/learn/macos/mastering-nsstatusbar-custom-macos-menu-bar-applications), [TechConcepts 2026 guide](https://techconcepts.org/blog/macos-menu-bar-guide).

---

## 5. Licensing summary

| Dependency | License | Compatible? |
|---|---|---|
| swift-argument-parser | Apache-2.0 | Permissive; not MIT but widely accepted |
| TauTUI | MIT | Yes |
| SwiftTerm | MIT | Yes |
| Splash | MIT | Yes |
| ANSIKit | MIT | Yes |
| terminal-input | MIT | Yes |

All Swift-native TUI/helper libraries found are MIT. The one non-MIT candidate is `swift-argument-parser`, which is Apache-2.0.

---

## 6. Recommendation

**Use a dependency-free ANSI picker for the interactive preset picker.**

Rationale:

- The requirement is a one-screen, arrow-key + Enter list. That is a small, bounded surface.
- No mature BubbleTea equivalent exists for Swift; TauTUI is promising but Swift 6–only and young.
- Adding a TUI library for this use case is over-engineering; a focused ANSI implementation keeps DockSwap's dependency surface small and avoids pulling in a framework whose API may still shift.
- `swift-argument-parser` should still be used for the CLI surface (`dockswap list`, `dockswap apply`, etc.); it is the right abstraction for flags/subcommands and is production-hardened.
- If DockSwap later grows richer terminal UI needs (multi-screen workflows, markdown preview, etc.), re-evaluate TauTUI at that point.

**Recommended approach:** `swift-argument-parser` + dependency-free ANSI raw-mode picker for interactive selection, with `NSStatusItem` if a menu-bar companion is desired.

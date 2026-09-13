import AppKit
import Foundation
import DockSwapCore

// KNOWN ISSUE (as of macOS 26 "Tahoe"): this NSStatusItem does not render
// visibly anywhere — not in the main menu bar, not in Control Center's
// "BentoBox" overflow container, even after forcing every hidden slot
// visible via `defaults write com.apple.controlcenter`. Verified via debug
// logging that the item is genuinely created (isVisible == true, valid
// button, icon loads) and via `System Events` that the process runs
// correctly as a background-only app, but `visible` is reported false at
// the process level (unlike a normal windowed app, which reports true —
// see DockSwapEditor). Properly bundled as a real .app with a matching
// CFBundleIdentifier/code-signature identifier, ad-hoc signed with the
// hardened runtime flag — no change.
//
// Confirmed via research (2026-09-13): this is a known, widespread,
// currently-unfixable OS bug, not specific to this app or its signing.
// Multiple properly signed-and-notarized third-party apps hit the
// identical symptom — status item exists in-process, Control Center never
// hosts it — including CodexBar (github.com/steipete/CodexBar/issues/3377,
// which explicitly ruled out signing as the cause) and BetterDisplay
// (github.com/waydabber/BetterDisplay/issues/5314). An Apple DTS engineer
// reproduced it directly on the Apple Developer Forums
// (developer.apple.com/forums/thread/806691), filed it as FB21015611, and
// called it "likely unfixable app-side." A real Apple Developer ID is
// therefore NOT a documented or evidenced fix — CodexBar has one and is
// broken the same way.
//
// Decision: parked, not abandoned. Revisit only once Apple ships a fix for
// FB21015611 (or an equivalent report) — no further app-side workaround is
// worth chasing until then. The CLI + TUI, and now DockSwapEditor (a normal
// windowed app, unaffected since it doesn't go through Control Center's
// hosting path at all), already cover real usage.

/// Menu bar companion to the `dockswap` CLI (BUILD-PLAYBOOK.md's post-MVP
/// GUI). Lists saved presets; clicking one switches to it. Save/delete stay
/// CLI-only for now — this just needs to be the fast "switch" surface.
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let icon = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "DockSwap") {
            icon.isTemplate = true
            statusItem.button?.image = icon
        } else {
            statusItem.button?.title = "Dock"
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let presets = (try? DockPreset.list()) ?? []
        if presets.isEmpty {
            let item = NSMenuItem(title: "No presets found", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            for preset in presets {
                let item = NSMenuItem(title: preset.name, action: #selector(switchToPreset(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = preset
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit DockSwap", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func switchToPreset(_ sender: NSMenuItem) {
        guard let preset = sender.representedObject as? DockPreset else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let engine = DockDiffEngine(dockUtil: try DockUtil.resolved())
                _ = try engine.apply(preset)
            } catch {
                // MVP: no UI feedback on failure yet; `dockswap switch` in a
                // terminal is still the way to see the actual error.
            }
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // menu bar only: no Dock icon, no window
app.run()

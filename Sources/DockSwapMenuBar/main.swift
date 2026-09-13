import AppKit
import Foundation
import DockSwapCore

// KNOWN ISSUE (as of macOS 26 "Tahoe"): this NSStatusItem does not render
// visibly anywhere — not in the main menu bar, not in Control Center's
// "BentoBox" overflow container, even after forcing every hidden slot
// visible via `defaults write com.apple.controlcenter`. Verified via debug
// logging that the item is genuinely created (isVisible == true, valid
// button, icon loads) and via `System Events` that the process runs
// correctly as a background-only app. Properly bundled as a real .app with
// a matching CFBundleIdentifier/code-signature identifier, ad-hoc signed
// with the hardened runtime flag (matching how a known-working third-party
// menu bar app is signed) — no change. The one remaining, unverified
// difference from that known-working app is a real Apple Developer ID
// signature (this app only has one available: TeamIdentifier=not set).
// Leaving this as real, reusable, buildable code — the CLI + TUI already
// ship and work fully — but the actual menu bar rendering is blocked on
// something about this OS version's status-item hosting that postdates
// available documentation. Revisit with either a real Developer ID to test
// signing properly, or once this is better understood.

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

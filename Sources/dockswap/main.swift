import Foundation
import ArgumentParser
import DockSwapCore

/// The `dockswap` CLI.
@main
struct DockSwap: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dockswap",
        abstract: "Save and switch macOS Dock presets",
        version: "1.0.0",
        subcommands: [Save.self, Switch.self, List.self, Delete.self],
        defaultSubcommand: Picker.self
    )

    /// Honours the exit-code contract (ticket 004): usage errors exit 1
    /// (argument-parser's default is 64), and DockSwapError maps to 2-6.
    static func main() {
        do {
            var command = try parseAsRoot()
            try command.run()
        } catch {
            if let e = error as? DockSwapError {
                FileHandle.standardError.write(Data("\(e.description)\n".utf8))
                Foundation.exit(e.exitCode)
            } else {
                // ArgumentParser's own errors (help/version requests, unknown
                // option, etc.) aren't publicly typed, but fullMessage(for:)/
                // exitCode(for:) are the sanctioned public API for rendering them.
                let message = DockSwap.fullMessage(for: error)
                if DockSwap.exitCode(for: error) == .success {
                    print(message)
                    Foundation.exit(0)
                } else {
                    FileHandle.standardError.write(Data("\(message)\n".utf8))
                    // Ticket 004 pins usage/validation errors to exit 1, not
                    // ArgumentParser's default EX_USAGE (64).
                    Foundation.exit(1)
                }
            }
        }
    }
}

/// Stable `list --json` shape (ticket 004).
struct ListSummary: Codable {
    let name: String
    let apps: Int
    let others: Int
    let updatedAt: String
}

/// Save the current dock as a preset.
struct Save: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Save the current dock as a preset"
    )

    @Argument(help: "The name of the preset")
    var name: String

    mutating func run() throws {
        let engine = DockDiffEngine(dockUtil: try DockUtil.resolved())
        let preset = try engine.captureCurrentPreset()
        try preset.save(to: name)
        print("Saved '\(name)' (\(preset.apps.count) apps, \(preset.others.count) others).")
    }
}

/// Switch to a preset.
struct Switch: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Switch to a preset"
    )

    @Argument(help: "The name of the preset")
    var name: String

    @Flag(name: .shortAndLong, help: "Show what would be changed without applying")
    var dryRun = false

    @Flag(name: .shortAndLong, help: "Suppress informational output")
    var quiet = false

    mutating func run() throws {
        let preset = try DockPreset.load(named: name)
        let engine = DockDiffEngine(dockUtil: try DockUtil.resolved())
        if dryRun {
            let (removes, adds) = diff(preset, from: try engine.captureCurrentPreset())
            print("Would switch to '\(name)':")
            print("  remove: \(removes.map { $0.item.description }.joined(separator: ", "))")
            print("  add:    \(adds.map { $0.item.description }.joined(separator: ", "))")
        } else {
            let result = try engine.apply(preset)
            if !quiet {
                if let (removed, added) = result {
                    print("Switched to '\(name)' (\(removed) removed, \(added) added).")
                } else {
                    print("already applied.")
                }
            }
        }
    }
}

/// List presets.
struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List presets"
    )

    @Flag(name: .shortAndLong, help: "Output as JSON")
    var json = false

    @Flag(name: .shortAndLong, help: "Suppress informational output")
    var quiet = false

    mutating func run() throws {
        let presets = try DockPreset.list()
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let summaries = presets.map {
                ListSummary(name: $0.name, apps: $0.apps.count, others: $0.others.count, updatedAt: $0.updatedAt)
            }
            let data = try encoder.encode(summaries)
            print(String(data: data, encoding: .utf8)!)
        } else if !quiet {
            let nameWidth = presets.map(\.name.count).max() ?? 0
            for preset in presets {
                let itemCount = preset.apps.count + preset.others.count
                let name = preset.name.padding(toLength: nameWidth, withPad: " ", startingAt: 0)
                print("\(name)  \(itemCount) items  \(preset.updatedAt)")
            }
        }
    }
}

/// Delete a preset.
struct Delete: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Delete a preset"
    )

    @Argument(help: "The name of the preset")
    var name: String

    @Flag(name: .shortAndLong, help: "Suppress informational output")
    var quiet = false

    mutating func run() throws {
        try DockPreset.delete(named: name)
        if !quiet {
            print("Deleted '\(name)'.")
        }
    }
}

/// The TUI picker.
struct Picker: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Open the TUI picker"
    )

    mutating func run() throws {
        let presets = try DockPreset.list()
        guard !presets.isEmpty else {
            print("No presets found")
            return
        }

        guard let selected = try ANSIPicker(presets: presets).run() else {
            print("Cancelled")
            return
        }

        let engine = DockDiffEngine(dockUtil: try DockUtil.resolved())
        let result = try engine.apply(selected)
        if let (removed, added) = result {
            print("Switched to '\(selected.name)' (\(removed) removed, \(added) added).")
        } else {
            print("already applied.")
        }
    }
}
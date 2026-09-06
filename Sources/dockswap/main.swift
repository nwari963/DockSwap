import Foundation
import ArgumentParser

/// The `dockswap` CLI.
@main
struct DockSwap: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Save and switch macOS Dock presets",
        subcommands: [Save.self, Switch.self, List.self, Delete.self],
        defaultSubcommand: Picker.self
    )
}

/// Save the current dock as a preset.
struct Save: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Save the current dock as a preset"
    )

    @Argument(help: "The name of the preset")
    var name: String

    mutating func run() throws {
        let engine = DockDiffEngine()
        let preset = try engine.captureLiveDock()
        try preset.save(to: name)
        print("Saved preset \"\"\(name)\"\"")
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
    var dryRun: Bool

    @Flag(name: .shortAndLong, help: "Suppress informational output")
    var quiet: Bool

    mutating func run() throws {
        let preset = try DockPreset.load(named: name)
        let engine = DockDiffEngine()
        if dryRun {
            let (removes, adds) = preset.diff(from: try engine.captureLiveDock())
            print("Would remove: \(removes.map { $0.item.description }.joined(separator: ", "))")
            print("Would add: \(adds.map { $0.item.description }.joined(separator: ", "))")
        } else {
            let changed = try engine.apply(preset)
            if !quiet {
                print(changed ? "Switched to preset \"\"\(name)\"\"" : "Already applied")
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
    var json: Bool

    @Flag(name: .shortAndLong, help: "Suppress informational output")
    var quiet: Bool

    mutating func run() throws {
        let presets = try DockPreset.list()
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(presets)
            print(String(data: data, encoding: .utf8)!)
        } else if !quiet {
            for preset in presets {
                print("- \(preset.name)")
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
    var quiet: Bool

    mutating func run() throws {
        try DockPreset.delete(named: name)
        if !quiet {
            print("Deleted preset \"\"\(name)\"\"")
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

        // TODO: Implement TUI picker
        print("TUI picker not implemented yet")
    }
}
